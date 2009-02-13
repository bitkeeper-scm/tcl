/*
 * tclMacOSXBundle.c --
 *
 *	This file implements functions that inspect CFBundle structures on
 *	MacOS X.
 *
 * Copyright 2001, Apple Computer, Inc.
 * Copyright (c) 2003-2007 Daniel A. Steffen <das@users.sourceforge.net>
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 *
 *	The following terms apply to all files originating from Apple
 *	Computer, Inc. ("Apple") and associated with the software unless
 *	explicitly disclaimed in individual files.
 *
 *	Apple hereby grants permission to use, copy, modify, distribute, and
 *	license this software and its documentation for any purpose, provided
 *	that existing copyright notices are retained in all copies and that
 *	this notice is included verbatim in any distributions. No written
 *	agreement, license, or royalty fee is required for any of the
 *	authorized uses. Modifications to this software may be copyrighted by
 *	their authors and need not follow the licensing terms described here,
 *	provided that the new terms are clearly indicated on the first page of
 *	each file where they apply.
 *
 *	IN NO EVENT SHALL APPLE, THE AUTHORS OR DISTRIBUTORS OF THE SOFTWARE
 *	BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR
 *	CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OF THIS SOFTWARE, ITS
 *	DOCUMENTATION, OR ANY DERIVATIVES THEREOF, EVEN IF APPLE OR THE
 *	AUTHORS HAVE BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. APPLE,
 *	THE AUTHORS AND DISTRIBUTORS SPECIFICALLY DISCLAIM ANY WARRANTIES,
 *	INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 *	MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND
 *	NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, AND
 *	APPLE,THE AUTHORS AND DISTRIBUTORS HAVE NO OBLIGATION TO PROVIDE
 *	MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
 *
 *	GOVERNMENT USE: If you are acquiring this software on behalf of the
 *	U.S. government, the Government shall have only "Restricted Rights" in
 *	the software and related documentation as defined in the Federal
 *	Acquisition Regulations (FARs) in Clause 52.227.19 (c) (2). If you are
 *	acquiring the software on behalf of the Department of Defense, the
 *	software shall be classified as "Commercial Computer Software" and the
 *	Government shall have only "Restricted Rights" as defined in Clause
 *	252.227-7013 (c) (1) of DFARs. Notwithstanding the foregoing, the
 *	authors grant the U.S. Government and others acting in its behalf
 *	permission to use and distribute the software in accordance with the
 *	terms specified in this license.
 *
 * RCS: @(#) $Id$
 */

#include "tclPort.h"

#ifdef HAVE_COREFOUNDATION
#include <CoreFoundation/CoreFoundation.h>
#include <mach-o/dyld.h>
#endif /* HAVE_COREFOUNDATION */

/*
 *----------------------------------------------------------------------
 *
 * Tcl_MacOSXOpenBundleResources --
 *
 *	Given the bundle name for a shared library, this routine sets
 *	libraryPath to the Resources/Scripts directory in the framework
 *	package. If hasResourceFile is true, it will also open the main
 *	resource file for the bundle.
 *
 * Results:
 *	TCL_OK if the bundle could be opened, and the Scripts folder found.
 *	TCL_ERROR otherwise.
 *
 * Side effects:
 *	libraryVariableName may be set, and the resource file opened.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_MacOSXOpenBundleResources(
    Tcl_Interp *interp,
    const char *bundleName,
    int hasResourceFile,
    int maxPathLen,
    char *libraryPath)
{
    return Tcl_MacOSXOpenVersionedBundleResources(interp, bundleName,
	    NULL, hasResourceFile, maxPathLen, libraryPath);
}

/*
 *----------------------------------------------------------------------
 *
 * Tcl_MacOSXOpenVersionedBundleResources --
 *
 *	Given the bundle and version name for a shared library (version name
 *	can be NULL to indicate latest version), this routine sets libraryPath
 *	to the Resources/Scripts directory in the framework package. If
 *	hasResourceFile is true, it will also open the main resource file for
 *	the bundle.
 *
 * Results:
 *	TCL_OK if the bundle could be opened, and the Scripts folder found.
 *	TCL_ERROR otherwise.
 *
 * Side effects:
 *	libraryVariableName may be set, and the resource file opened.
 *
 *----------------------------------------------------------------------
 */

int
Tcl_MacOSXOpenVersionedBundleResources(
    Tcl_Interp *interp,
    const char *bundleName,
    const char *bundleVersion,
    int hasResourceFile,
    int maxPathLen,
    char *libraryPath)
{
#ifdef HAVE_COREFOUNDATION
    CFBundleRef bundleRef, versionedBundleRef = NULL;
    CFStringRef bundleNameRef;
    CFURLRef libURL;

    libraryPath[0] = '\0';

    bundleNameRef = CFStringCreateWithCString(NULL, bundleName,
	    kCFStringEncodingUTF8);

    bundleRef = CFBundleGetBundleWithIdentifier(bundleNameRef);
    CFRelease(bundleNameRef);

    if (bundleVersion && bundleRef) {
	/*
	 * Create bundle from bundleVersion subdirectory of 'Versions'.
	 */

	CFURLRef bundleURL = CFBundleCopyBundleURL(bundleRef);

	if (bundleURL) {
	    CFStringRef bundleVersionRef = CFStringCreateWithCString(NULL,
		    bundleVersion, kCFStringEncodingUTF8);

	    if (bundleVersionRef) {
		CFStringRef bundleTailRef = CFURLCopyLastPathComponent(
			bundleURL);

		if (bundleTailRef) {
		    if (CFStringCompare(bundleTailRef, bundleVersionRef, 0) ==
			    kCFCompareEqualTo) {
			versionedBundleRef = (CFBundleRef) CFRetain(bundleRef);
		    }
		    CFRelease(bundleTailRef);
		}
		if (!versionedBundleRef) {
		    CFURLRef versURL = CFURLCreateCopyAppendingPathComponent(
			    NULL, bundleURL, CFSTR("Versions"), TRUE);

		    if (versURL) {
			CFURLRef versionedBundleURL =
				CFURLCreateCopyAppendingPathComponent(
				NULL, versURL, bundleVersionRef, TRUE);
			if (versionedBundleURL) {
			    versionedBundleRef = CFBundleCreate(NULL,
				    versionedBundleURL);
			    CFRelease(versionedBundleURL);
			}
			CFRelease(versURL);
		    }
		}
		CFRelease(bundleVersionRef);
	    }
	    CFRelease(bundleURL);
	}
	if (versionedBundleRef) {
	    bundleRef = versionedBundleRef;
	}
    }

    if (bundleRef) {
	if (hasResourceFile) {
	    /*
	     * Dynamically acquire address for CFBundleOpenBundleResourceMap
	     * symbol, since it is only present in full CoreFoundation on Mac
	     * OS X and not in CFLite on pure Darwin.
	     */

	    static int initialized = FALSE;
	    static short (*openresourcemap)(CFBundleRef) = NULL;

	    if (!initialized) {
		NSSymbol nsSymbol = NULL;
		if (NSIsSymbolNameDefinedWithHint(
			"_CFBundleOpenBundleResourceMap", "CoreFoundation")) {
		    nsSymbol = NSLookupAndBindSymbolWithHint(
			    "_CFBundleOpenBundleResourceMap","CoreFoundation");
		    if (nsSymbol) {
			openresourcemap = NSAddressOfSymbol(nsSymbol);
		    }
		}
		initialized = TRUE;
	    }

	    if (openresourcemap) {
		short refNum;

		refNum = openresourcemap(bundleRef);
	    }
	}

	libURL = CFBundleCopyResourceURL(bundleRef, CFSTR("Scripts"),
		NULL, NULL);

	if (libURL) {
	    /*
	     * FIXME: This is a quick fix, it is probably not right for
	     * internationalization.
	     */

	    CFURLGetFileSystemRepresentation(libURL, TRUE,
		    (unsigned char*) libraryPath, maxPathLen);
	    CFRelease(libURL);
	}
	if (versionedBundleRef) {
	    CFRelease(versionedBundleRef);
	}
    }

    if (libraryPath[0]) {
	return TCL_OK;
    } else {
	return TCL_ERROR;
    }
#else  /* HAVE_COREFOUNDATION */
    return TCL_ERROR;
#endif /* HAVE_COREFOUNDATION */
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
