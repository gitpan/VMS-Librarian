/*
** Copyright (c) 2003, Dick Munroe (munroe@csworks.com),
**		       Cottage Software Works, Inc.
**		       All rights reserved.
**
** This program, comes with ABSOLUTELY NO WARRANTY.
** This is free software, and you are welcome to redistribute it
** under the conditions of the GNU GENERAL PUBLIC LICENSE, version 2.
**
** This code was originally written by Brad Hughes.  It's been
** extensively extended to more fully support the lbr routines by Dick
** Munroe.
**
** The XS code for VMS::Librarian
**
** Revision History:
**
**  1.01    11-May-2003	Dick Munroe (munroe@csworks.com)
**	    Make the input buffer size for get_module as big as it can
**	    be.  Make sure that the extended status information is
**	    always valid.
*/

#include <credef.h>
#include <descrip.h>
#include <lbr$routines.h>
#include <lbrdef.h>
#include <lhidef.h>
#include <lib$routines.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <ssdef.h>
#include <starlet.h>
#include <str$routines.h>
#include <stsdef.h>
#include <syidef.h>

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

typedef struct dsc$descriptor_d dsc$descriptor_d ;
typedef struct dsc$descriptor_s dsc$descriptor_s ;

/* 
 * These constants should really be mapped from imagelib.olb,
 * but then you can't use them in a select.  Well, maybe you
 * can, but I sure don't know how...
 */

#define LBR$_NORMAL      2523137
#define LBR$_KEYINDEX    2523145
#define LBR$_KEYINS      2523153
#define LBR$_OLDLIBRARY  2523161
#define LBR$_NOHISTORY   2524163
#define LBR$_EMPTYHIST   2524171
#define LBR$_HDRTRUNC    2525184
#define LBR$_NOUPDHIST   2525192
#define LBR$_NULIDX      2525200
#define LBR$_OLDMISMCH   2525208
#define LBR$_RECTRUNC    2525216
#define LBR$_STILLKEYS   2525224
#define LBR$_TYPMISMCH   2525232
#define LBR$_NOMTCHFOU   2525240
#define LBR$_ERRCLOSE    2525248
#define LBR$_ENDTOPIC    2525256
#define LBR$_ALLWRNGBLK  2527234
#define LBR$_DUPKEY      2527242
#define LBR$_ILLCTL      2527250
#define LBR$_ILLCREOPT   2527258
#define LBR$_ILLIDXNUM   2527266
#define LBR$_ILLFMT      2527274
#define LBR$_ILLFUNC     2527282
#define LBR$_ILLOP       2527290
#define LBR$_ILLTYP      2527298
#define LBR$_INVKEY      2527306
#define LBR$_INVNAM      2527314
#define LBR$_INVRFA      2527322
#define LBR$_KEYNOTFND   2527330
#define LBR$_LIBNOTOPN   2527338
#define LBR$_LKPNOTDON   2527346
#define LBR$_LIBOPN      2527354
#define LBR$_NOFILNAM    2527362
#define LBR$_NOHLPTXT    2527370
#define LBR$_NOTHLPLIB   2527378
#define LBR$_RECLNG      2527386
#define LBR$_REFCNTZERO  2527394
#define LBR$_RFAPASTEOF  2527402
#define LBR$_TOOMNYLIB   2527410
#define LBR$_UPDURTRAV   2527418
#define LBR$_BADPARAM    2527426
#define LBR$_INTRNLERR   2527434
#define LBR$_WRITEERR    2527442
#define LBR$_ILLOUTROU   2527450
#define LBR$_ILLOUTWID   2527458
#define LBR$_ILLINROU    2527466
#define LBR$_TOOMNYARG   2527474

static void				freeKeys() ;
static void				reallocKeys() ;
static unsigned long			getKeys() ;

static long				keyCount = 0 ;
static long				keyCountMaximum = 0 ;
static dsc$descriptor_d*		keys = NULL ;

static unsigned long			lbr$_normal = LBR$_NORMAL ;
static unsigned long			ss$_normal = SS$_NORMAL ;

static int vlib_debug = 0;

static int
not_here(s)
char *s;
{
    croak("%s not implemented on this architecture", s);
    return -1;
}

static unsigned long
addModule (
    unsigned int libindex, 
    char* key, 
    AV* data, 
    int theDebug)
{
    int					theDataLength = av_len(data) ;
    int					theIndex ;
    dsc$descriptor_s			theKey = {strlen(key), DSC$K_DTYPE_T, DSC$K_CLASS_S, key} ;
    unsigned long			theRFA[2] ;
    unsigned long			theStatus ;

    if (theDebug) printf ("In addModule[%s]...\n", key);

    for (theIndex = 0; theIndex <= theDataLength; theIndex++)
    {
	dsc$descriptor_s		theData = {0, DSC$K_DTYPE_T, DSC$K_CLASS_S, 0} ;
	unsigned int			theLength ;
	SV**				theSvPP ;

	theSvPP = av_fetch(data, theIndex, 0) ;
	theData.dsc$a_pointer = SvPV(*theSvPP, theLength) ;
	theData.dsc$w_length = theLength ;

	theStatus = lbr$put_record(&libindex, &theData, theRFA) ;

	if (! $VMS_STATUS_SUCCESS(theStatus))
	{
	    if (theDebug) printf ("Error [%08x] in addModule(%s) from lbr$put_record(%d);\n", theStatus, key, theIndex);
	    return theStatus ;
	}
    }

    theStatus = lbr$put_end(&libindex) ;

    if (! $VMS_STATUS_SUCCESS(theStatus))
    {
	if (theDebug) printf ("Error [%08x] in addModule(%s) XS from lbr$put_end;\n", theStatus, key);
	return theStatus ;
    }

    theStatus = lbr$insert_key(&libindex, &theKey, theRFA) ;

    if (! $VMS_STATUS_SUCCESS(theStatus))
    {
	if (theDebug) printf ("Error [%08x] in addModule(%s) XS from lbr$insert_key(%s);\n", theStatus, key, key);
    }

    return theStatus ;
}

static unsigned long
deleteModule (
    int theLibraryIndex, 
    char* key,
    int theDebug)
{
    unsigned long			theIndex ;
    dsc$descriptor_s			theKey = {strlen(key), DSC$K_DTYPE_T, DSC$K_CLASS_S, key} ;
    unsigned long			theRFA[2] ;
    unsigned long			theStatus ;

    if (theDebug) printf("In deleteModule(%s)\n", key) ;

    theStatus = lbr$lookup_key(&theLibraryIndex, &theKey, theRFA) ;

    if (theDebug) printf("Status [%08X] returned from lbr$lookup_key\n",theStatus) ;

    if (! $VMS_STATUS_SUCCESS(theStatus))
    {
	return theStatus ;
    }

    for (theIndex = 1; theIndex <= 8; theIndex++)
    {
	unsigned long			theModuleIndex ;

	freeKeys() ;

	theStatus = lbr$set_index(&theLibraryIndex, &theIndex) ;

	if (theDebug) printf("Status [%08X] returned from lbr$set_index(%d)\n",theStatus, theIndex) ;

	if (theStatus == LBR$_ILLIDXNUM)
	{
	    break ;
	}

	if (! $VMS_STATUS_SUCCESS(theStatus))
	{
	    return theStatus ;
	}

	theStatus = lbr$search(&theLibraryIndex, &theIndex, theRFA, getKeys) ;

	if (theDebug) printf("Status [%08X] returned from lbr$search\n",theStatus) ;

	if (theStatus == LBR$_KEYNOTFND)
	{
	    continue ;
	}

	if (! $VMS_STATUS_SUCCESS(theStatus))
	{
	    freeKeys() ;
	    return theStatus ;
	}

	for (theModuleIndex = 0; theModuleIndex < keyCount; theModuleIndex++)
	{
	    
	    theStatus = lbr$delete_key(&theLibraryIndex, &keys[theModuleIndex]) ;

	    if (theDebug) 
		printf(
		    "Status [%08X] returned from lbr$delete_key(%0.*s)\n",
		    theStatus, 
		    keys[theModuleIndex].dsc$w_length,
		    keys[theModuleIndex].dsc$a_pointer) ;

	    if (! $VMS_STATUS_SUCCESS(theStatus))
	    {
		freeKeys() ;
		return theStatus ;
	    }
	}

	freeKeys() ;
    }

    theStatus = lbr$delete_data(&theLibraryIndex, theRFA) ;

    if (theDebug) printf("Status [%08X] returned from lbr$delete_data\n",theStatus) ;

    return theStatus ;
}

/*
** The architecture independent type (VLIB_OBJECT, VLIB_IMAGE)
** return different values depending on the architecture of the
** processor running the xsub.
*/

static double
constant(name, arg)
char *name;
int arg;
{
    unsigned long			theArchitecture = SYI$_ARCH_TYPE ;
    
    lib$getsyi(&theArchitecture, &theArchitecture, 0, 0, 0, 0) ;

    errno = 0;

    if (vlib_debug) printf ("In constant XS - name [%s]...\n",name);
    if (vlib_debug) printf ("In constant(%s) XS architecture is %d.\n", name, theArchitecture) ;

    if (strEQ(name, "VLIB_CREATE")) return LBR$C_CREATE;
    if (strEQ(name, "VLIB_READ"))   return LBR$C_READ;
    if (strEQ(name, "VLIB_UPDATE")) return LBR$C_UPDATE;

    if (strEQ(name, "VLIB_UNKNOWN")) return LBR$C_TYP_UNK;
    if (strEQ(name, "VLIB_ALPHA_OBJECT")) return LBR$C_TYP_EOBJ;
    if (strEQ(name, "VLIB_VAX_OBJECT")) return LBR$C_TYP_OBJ;
    if (strEQ(name, "VLIB_OBJECT")) return (theArchitecture == 1 ? LBR$C_TYP_OBJ : LBR$C_TYP_EOBJ) ;
    if (strEQ(name, "VLIB_MACRO"))  return LBR$C_TYP_MLB;
    if (strEQ(name, "VLIB_HELP"))   return LBR$C_TYP_HLP;
    if (strEQ(name, "VLIB_TEXT"))   return LBR$C_TYP_TXT;
    if (strEQ(name, "VLIB_ALPHA_IMAGE"))  return LBR$C_TYP_ESHSTB;
    if (strEQ(name, "VLIB_VAX_IMAGE"))  return LBR$C_TYP_SHSTB;
    if (strEQ(name, "VLIB_IMAGE"))  return (theArchitecture == 1 ? LBR$C_TYP_SHSTB : LBR$C_TYP_ESHSTB);

    if (strEQ(name, "VLIB_CRE_VMSV2"))  return CRE$C_VMSV2 ;
    if (strEQ(name, "VLIB_CRE_VMSV3"))  return CRE$C_VMSV3 ;
    if (strEQ(name, "VLIB_CRE_NOCASECMP"))  return CRE$M_NOCASECMP ;
    if (strEQ(name, "VLIB_CRE_NOCASENTR"))  return CRE$M_NOCASENTR ;
    if (strEQ(name, "VLIB_CRE_UPCASNTRY"))  return CRE$M_UPCASNTRY ;
    if (strEQ(name, "VLIB_CRE_HLPCASING"))  return CRE$C_HLPCASING ;
    if (strEQ(name, "VLIB_CRE_OBJCASING"))  return CRE$C_OBJCASING ;
    if (strEQ(name, "VLIB_CRE_MACTXTCAS"))  return CRE$C_MACTXTCAS ;
    
    if (vlib_debug) printf ("Error in constant XS; name [%s] not found.\n",name);

    errno = EINVAL;
    return 0;
}

/*
** Extract an integer value from a hash and return it.
*/

static int
getSvIVfromHV(HV* theHash, char* key)
{
    SV** theSvPP ;

    theSvPP = hv_fetch(theHash, key, strlen(key), 0) ;
    if (theSvPP == NULL)
    {
	croak("Key \"%s\" not found.\n", key) ;
    }
    else
    {
	if (SvIOK(*theSvPP) || SvNOK(*theSvPP))
	{
	    return SvIV(*theSvPP) ;
	}
	else
	{
	    croak("Key \"%s\" is the wrong type (%d).\n", key, SvTYPE(*theSvPP)) ;
	}
    }
}

/*
** The following routine is used to scan a key index and puts the
** discovered keys on the stack to be returned later.
**
** This routine is NOT thread safe.  The problem is that the LBR
** routines have no way to put user state into these callbacks.
*/

static void
freeKeys()
{
    long				i ;

    for (i = 0; i < keyCount; i++)
    {
	if (keys[i].dsc$a_pointer != NULL)
	{
	    str$free1_dx (&keys[i]) ;
	}
    }

    free(keys) ;

    keyCount = keyCountMaximum = 0 ;
    keys = NULL ;
}

static void
reallocKeys()
{
    long				i ;
    long				newKeyCount ;
    long				oldKeyCount ;

    oldKeyCount = keyCountMaximum ;
    newKeyCount = (oldKeyCount ? 2 * oldKeyCount : 100) ;
    keys = realloc(keys, newKeyCount * sizeof(dsc$descriptor_d)) ;
    for (i = oldKeyCount; i < newKeyCount; i++)
    {
	keys[i].dsc$w_length = 0 ;
	keys[i].dsc$b_dtype = DSC$K_DTYPE_T ;
	keys[i].dsc$b_class = DSC$K_CLASS_D ;
	keys[i].dsc$a_pointer = NULL ;
    }
    keyCountMaximum = newKeyCount ;
}

static unsigned long
getKeys(
    struct dsc$descriptor* theKeyName,
    unsigned long* theRFA)
{
    if (keyCount >= keyCountMaximum)
    {
	reallocKeys() ;
    }

    str$copy_dx (&keys[keyCount], theKeyName) ;
    keyCount++ ;
    return SS$_NORMAL ;
}
    
MODULE = VMS::Librarian		PACKAGE = VMS::Librarian		

double
constant(name,arg)
    char *	name
    int		arg

#
# The module is inserted into the current index.
#

int
lbr_add_module (libindex, key, data, debug)
    unsigned int libindex
    char* key
    AV * data
    int debug

  CODE:
    int					theDataLength = av_len(data) ;
    int					theDebug = vlib_debug || (debug&2) ;
    dsc$descriptor_s			theKey = {strlen(key), DSC$K_DTYPE_T, DSC$K_CLASS_S, key} ;
    unsigned long			theRFA[2] ;
    unsigned long			theStatus ;

    if (theDebug) printf ("In lbr_add_module XS for key [%s]...\n", key);

    if (theDataLength < 0)
    {
	if (theDebug) printf("Error: No data passed to lbr_add_module(%s) XS", key) ;
	XSRETURN_EMPTY ;
    }

    theStatus = lbr$lookup_key(&libindex, &theKey, theRFA) ;

    if ($VMS_STATUS_SUCCESS(theStatus))
    {
	if (theDebug) printf("Error: key [%s] already exists\n", key) ;
	SETERRNO(EVMSERR, theStatus) ;
	XSRETURN_EMPTY ;
    }

    theStatus = addModule(libindex, key, data, theDebug) ;

    if (! $VMS_STATUS_SUCCESS(theStatus))
    {
	if (theDebug) printf ("Error [%08x] in lbr_add_module(%s) XS from addModule(%s);\n", theStatus, key, key);
	SETERRNO(EVMSERR, theStatus) ;
	XSRETURN_EMPTY ;
    }

    SETERRNO(EVMSERR, theStatus) ;

    RETVAL = 1 ;

  OUTPUT:
    RETVAL

int
lbr_close (libindex, debug)
    unsigned int libindex
    int debug

  CODE:
    int theStatus = 0;
    int theDebug = 0;

    theDebug = vlib_debug || (debug & 2);
    if (theDebug) printf ("In lbr_close XS for libindex [%d]...\n", libindex);

    theStatus = lbr$close (&libindex) ;

    if (! $VMS_STATUS_SUCCESS(theStatus))
    {
	if (theDebug) printf("Error [%08x] in lbr_close XS.\n", theStatus) ;
	SETERRNO(EVMSERR,theStatus);
	XSRETURN_EMPTY;
    }

    SETERRNO(EVMSERR, theStatus) ;

    RETVAL = 1;

  OUTPUT:
    RETVAL

int
lbr_connect_indices (libindex, key, keyIndex, keys, debug)
    int libindex
    char* key
    int keyIndex
    AV* keys
    int debug

  CODE:
    int					theDebug = vlib_debug || (debug&2) ;
    int					theIndex ;
    dsc$descriptor_s			theKey = {strlen(key), DSC$K_DTYPE_T, DSC$K_CLASS_S, key} ;
    int					theKeysLength = av_len(keys) ;
    unsigned long			theRFA[2] ;
    unsigned long			theStatus ;
    
    if (theKeysLength < 0)
    {
	if (theDebug) printf("Error: No keys passed to lbr_connect_indices(%s) XS", key) ;
	XSRETURN_EMPTY ;
    }

    #
    # The "master" key MUST appear in the current index.  The RFA returned
    # will be used as a link elsewhere.
    #

    theStatus = lbr$lookup_key(&libindex, &theKey, theRFA) ;

    if (! $VMS_STATUS_SUCCESS(theStatus))
    {
	if (theDebug) printf("Error [%08x] in lbr_connect_indices(%s) XS from lbr$lookup_key.\n", theStatus, key) ;
	SETERRNO(EVMSERR,theStatus);
	XSRETURN_EMPTY;
    }

    theStatus = lbr$set_index(&libindex, &keyIndex) ;

    if (! $VMS_STATUS_SUCCESS(theStatus))
    {
	if (theDebug) printf("Error [%08x] in lbr_connect_indices(%s) XS from lbr$set_index(%d).\n", theStatus, key, keyIndex) ;
	SETERRNO(EVMSERR,theStatus);
	XSRETURN_EMPTY;
    }

    #
    # The alternate keys must NOT appear in the alternate index.
    #

    for (theIndex = 0; theIndex <= theKeysLength; theIndex++)
    {
	dsc$descriptor_s		theAlternateKey = {0, DSC$K_DTYPE_T, DSC$K_CLASS_S, 0} ;
	unsigned int			theLength ;
	SV**				theSvPP ;

	theSvPP = av_fetch(keys, theIndex, 0) ;
	theAlternateKey.dsc$a_pointer = SvPV(*theSvPP, theLength) ;
	theAlternateKey.dsc$w_length = theLength ;

	theStatus = lbr$lookup_key(&libindex, &theAlternateKey, 0) ;

	if ($VMS_STATUS_SUCCESS(theStatus))
	{
	    if (theDebug) 
		printf(
		    "Error [%08x] in lbr_connect_indices(%s) XS from lbr$lookup_key(%0.*s).\n", 
		    theStatus, 
		    key,
		    theAlternateKey.dsc$w_length,
		    theAlternateKey.dsc$a_pointer) ;
	    SETERRNO(EVMSERR,theStatus);
	    XSRETURN_EMPTY;
	}
    }

    #
    # Insert the alternate keys.
    #

    for (theIndex = 0; theIndex <= theKeysLength; theIndex++)
    {
	dsc$descriptor_s		theAlternateKey = {0, DSC$K_DTYPE_T, DSC$K_CLASS_S, 0} ;
	unsigned int			theLength ;
	SV**				theSvPP ;

	theSvPP = av_fetch(keys, theIndex, 0) ;
	theAlternateKey.dsc$a_pointer = SvPV(*theSvPP, theLength) ;
	theAlternateKey.dsc$w_length = theLength ;

	theStatus = lbr$insert_key(&libindex, &theAlternateKey, theRFA) ;

	if (! $VMS_STATUS_SUCCESS(theStatus))
	{
	    if (theDebug) 
		printf(
		    "Error [%08x] in lbr_connect_indices(%s) XS from lbr$insert_key(%0.*s).\n", 
		    theStatus, 
		    key, 
		    theAlternateKey.dsc$w_length,
		    theAlternateKey.dsc$a_pointer) ;
	    SETERRNO(EVMSERR,theStatus);
	    XSRETURN_EMPTY;
	}
    }

    SETERRNO(EVMSERR, theStatus) ;

    RETVAL = 1 ;

  OUTPUT:
    RETVAL

int
lbr_delete_module (libindex, key, debug)
    int libindex
    char * key
    int debug

  CODE:
    int theStatus;
    int theDebug;

    theDebug = vlib_debug || (debug & 2);
    if (theDebug) printf ("In lbr_delete_module XS for key [%s]...\n", key);

    theStatus = deleteModule(libindex, key, theDebug);

    if (! $VMS_STATUS_SUCCESS(theStatus))
    {
	if (theDebug) printf ("Error [%08x] in lbr_delete_module XS from deleteModule;\n",theStatus);
	SETERRNO(EVMSERR,theStatus);
	XSRETURN_EMPTY;
    }

    if (theDebug) printf ("Leaving lbr_delete_module for key [%s]\n", key);

    SETERRNO(EVMSERR, theStatus) ;

    RETVAL = 1 ;

  OUTPUT:
    RETVAL

HV *
lbr_get_header(libindex, debug)
    int libindex
    int debug

  CODE:
    dsc$descriptor_d			theDateTime = {0, DSC$K_DTYPE_T, DSC$K_CLASS_D, NULL} ;
    struct lhidef			theHeader ;
    int					theStatus;
    int					theDebug;

    theDebug = vlib_debug || (debug & 2);
    if (theDebug) printf ("In lbr_get_header XS for libindex [%d...\n", libindex);

    theStatus = lbr$get_header(&libindex, &theHeader) ;

    if (! $VMS_STATUS_SUCCESS(theStatus))
    {
	if (theDebug) printf ("Error [%08x] in lbr_get_header XS from lbr$get_header;  returning empty.\n",theStatus);
	SETERRNO(EVMSERR,theStatus);
	XSRETURN_EMPTY;
    }

    RETVAL = newHV() ;

    {
	hv_store(RETVAL, "TYPE", 4,	    newSViv(theHeader.lhi$l_type), 0) ;
	hv_store(RETVAL, "NINDEX", 6,	    newSViv(theHeader.lhi$l_nindex), 0) ;
	hv_store(RETVAL, "MAJORID", 7,	    newSViv(theHeader.lhi$l_majorid), 0) ;
	hv_store(RETVAL, "MINORID", 7,	    newSViv(theHeader.lhi$l_minorid), 0) ;
	hv_store(RETVAL, "LBRVER", 6,	    newSVpv(&theHeader.lhi$t_lbrver[1], (int) theHeader.lhi$t_lbrver[0]), 0) ;
    
	lib$format_date_time(&theDateTime, &theHeader.lhi$l_credat) ;
	hv_store(RETVAL, "CREDAT", 6,	    newSVpv(theDateTime.dsc$a_pointer, theDateTime.dsc$w_length), 0) ;

	lib$format_date_time(&theDateTime, &theHeader.lhi$l_updtim) ;
	hv_store(RETVAL, "UPDTIM", 6,	    newSVpv(theDateTime.dsc$a_pointer, theDateTime.dsc$w_length), 0) ;
    
	hv_store(RETVAL, "UPDHIS", 6,	    newSViv(theHeader.lhi$l_updhis), 0) ;
	hv_store(RETVAL, "FREEVBN", 7,	    newSViv(theHeader.lhi$l_freevbn), 0) ;
	hv_store(RETVAL, "FREEBLK", 7,	    newSViv(theHeader.lhi$l_freeblk), 0) ;

        {
	    AV * theArray = newAV() ;
	    unsigned short * theRFA = (unsigned short*) &theHeader.lhi$b_nextrfa[0] ;

	    av_push(theArray, newSViv(theRFA[0])) ;
	    av_push(theArray, newSViv(theRFA[1])) ;
	    av_push(theArray, newSViv(theRFA[2])) ;

	    hv_store(RETVAL, "NEXTRFA", 7, newRV((SV*)theArray), 0) ;

	    #
	    # When the AV is created, the reference count is 1.  When
	    # the Reference to the AV is created, the reference count
	    # is incremented.  This gets it back to the right value.
	    #

	    SvREFCNT_dec( (SV*) theArray );
	}

	hv_store(RETVAL, "NEXTVBN", 7,	    newSViv(theHeader.lhi$l_nextvbn), 0) ;
	hv_store(RETVAL, "FREIDXBLK", 9,    newSViv(theHeader.lhi$l_freidxblk), 0) ;
	hv_store(RETVAL, "FREEIDX", 7,	    newSViv(theHeader.lhi$l_freeidx), 0) ;
	hv_store(RETVAL, "HIPREAL", 7,	    newSViv(theHeader.lhi$l_hipreal), 0) ;
	hv_store(RETVAL, "IDXBLKS", 7,	    newSViv(theHeader.lhi$l_idxblks), 0) ;
	hv_store(RETVAL, "IDXCNT", 6,	    newSViv(theHeader.lhi$l_idxcnt), 0) ;
	hv_store(RETVAL, "MODCNT", 6,	    newSViv(theHeader.lhi$l_modcnt), 0) ;
	hv_store(RETVAL, "MHDUSZ", 6,	    newSViv(theHeader.lhi$l_mhdusz), 0) ;
	hv_store(RETVAL, "MAXLUHREC", 9,    newSViv(theHeader.lhi$l_maxluhrec), 0) ;
	hv_store(RETVAL, "NUMLUHREC", 9,    newSViv(theHeader.lhi$l_numluhrec), 0) ;
	hv_store(RETVAL, "LIBSTATUS", 9,    newSViv(theHeader.lhi$l_libstatus), 0) ;

	str$free1_dx(&theDateTime) ;
    }

    SETERRNO(EVMSERR, theStatus) ;

    if (theDebug) printf ("Leaving lbr_get_header for libindex [%d]\n", libindex);
  OUTPUT:
    RETVAL
  CLEANUP:
    #
    # When the HV is created, the reference count is 1.  When
    # the Reference to the HV is created (details are in the
    # typemap that comes with VMS::Librarian), the reference count
    # is incremented.  This gets it back to the right value.
    #

    SvREFCNT_dec( (SV*) RETVAL );

AV *
lbr_get_keys(libindex, key, debug)
    int libindex
    char* key
    int debug

  CODE:
    int					theDebug;
    dsc$descriptor_s			theKey = {strlen(key), DSC$K_DTYPE_T, DSC$K_CLASS_S, key} ;
    int					theKeyIndex ;
    unsigned long			theRFA[2] ;
    unsigned long 			theStatus;

    theDebug = vlib_debug || (debug & 2);
    if (theDebug) printf ("In lbr_get_keys(%s) XS...\n", key);

    theStatus = lbr$lookup_key(&libindex, &theKey, theRFA) ;

    if (! $VMS_STATUS_SUCCESS(theStatus))
    {
	if (theDebug) printf ("Error [%08x] in lbr_get_keys(%s) XS from lbr$lookup_key(%s).\n", theStatus, key, key);
	SETERRNO(EVMSERR, theStatus);
	XSRETURN_EMPTY;
    }

    RETVAL = newAV() ;

    for (theKeyIndex = 1; theKeyIndex <= 8; theKeyIndex++)
    {
	AV*				theKeyAV ;
	unsigned long			theModuleIndex ;

	theStatus = lbr$search(&libindex, &theKeyIndex, theRFA, getKeys) ;

	if (theStatus == LBR$_ILLIDXNUM)
	{
	    break ;
	}

	if (theStatus == LBR$_KEYNOTFND)
	{
	    continue ;
	}

	if (! $VMS_STATUS_SUCCESS(theStatus))
	{
	    freeKeys() ;
	    av_undef(RETVAL) ;
	    SETERRNO(EVMSERR, theStatus);
	    XSRETURN_EMPTY;
	}

	theKeyAV = newAV() ;

	for (theModuleIndex = 0; theModuleIndex < keyCount; theModuleIndex++)
	{
	    if (theDebug) 
		printf(
		    "pushing [%d] = %0.*s\n", 
		    theModuleIndex, 
		    keys[theModuleIndex].dsc$w_length, 
		    keys[theModuleIndex].dsc$a_pointer) ;
	    av_push(theKeyAV, newSVpv(keys[theModuleIndex].dsc$a_pointer, keys[theModuleIndex].dsc$w_length)) ;
	}

	av_store(RETVAL, theKeyIndex, newRV_noinc((SV*)theKeyAV)) ;

	freeKeys() ;
    }

    SETERRNO(EVMSERR, theStatus) ;

    if (theDebug) printf ("Leaving lbr_get_keys for libindex [%d]\n", libindex);

  OUTPUT:
    RETVAL
  CLEANUP:
    #
    # When the AV is created, the reference count is 1.  When
    # the Reference to the AV is created (details are in the
    # typemap that comes with this extension), the reference count
    # is incremented.  This gets it back to the right value.
    #

    SvREFCNT_dec( (SV*) RETVAL );

void
lbr_get_index (libindex, keyIndex, debug)
    int libindex
    int keyIndex 
    int debug

  PPCODE:
    long				i ;
    unsigned long			theStatus ;
    int					theDebug ;

    theDebug = vlib_debug || (debug & 2);
    if (theDebug) printf ("In lbr_get_index XS for key index [%d]...\n", keyIndex);

    theStatus = lbr$get_index(&libindex, &keyIndex, &getKeys, 0);

    if (! $VMS_STATUS_SUCCESS(theStatus))
    {
	if (theDebug) printf ("Error [%08x] in lbr_get_index XS from lbr$get_index;\n",theStatus);
	SETERRNO(EVMSERR,theStatus);
	XSRETURN_EMPTY;
    }

    if (theDebug) printf("Pushing %d keys onto stack\n", keyCount) ;
    
    for (i = 0; i < keyCount; i++)
    {
	if (theDebug) printf ("%d:\"%0.*s\"\n", keyIndex, keys[i].dsc$w_length, keys[i].dsc$a_pointer) ;
	XPUSHs(sv_2mortal(newSVpv(keys[i].dsc$a_pointer, keys[i].dsc$w_length)));
    }

    freeKeys() ;
    
    SETERRNO(EVMSERR, theStatus) ;

    if (theDebug) printf ("Leaving lbr_get_index for key index [%d]\n", keyIndex);

void
lbr_get_module (libindex, key, debug)
    int libindex
    char * key
    int debug

  PPCODE:
    int k;
    int theStatus;
    int theDebug;

    char buffer[65536];
    dsc$descriptor_s			theBuffer = {65535, DSC$K_DTYPE_T, DSC$K_CLASS_S, buffer};
    dsc$descriptor_s			theData = {0, DSC$K_DTYPE_T, DSC$K_CLASS_S, 0};
    dsc$descriptor_s			theKey = {strlen(key), DSC$K_DTYPE_T, DSC$K_CLASS_S, key};
    unsigned long			theRFA[2] ;

    theDebug = vlib_debug || (debug & 2);
    if (theDebug) printf ("In lbr_get_module XS for key [%s]...\n", key);

    theStatus = lbr$lookup_key (&libindex, &theKey, &theRFA);

    if (theDebug) printf("Status [%08X] in lbr_get_module(%s) XS from lbr$lookup_key(%s)\n", theStatus, key, key) ;

    if (!$VMS_STATUS_SUCCESS(theStatus))
    {
	if (theDebug) printf ("Error [%08x] in lbr_get_module(%s) XS from lbr$lookup_key(%s).\n",theStatus, key, key);
	SETERRNO(EVMSERR,theStatus);
	XSRETURN_EMPTY;
    }

    while (SS$_NORMAL == (theStatus = lbr$get_record (&libindex, &theBuffer, &theData))) 
    {
	if (theDebug) printf ("[%3d] [%.*s]\n", theData.dsc$w_length, theData.dsc$w_length, theData.dsc$a_pointer);
	
	#
	# Make sure that all buffers have a null character at the
	# end.  newSVpv screws up for the case of 0 length records
	# and MAY do so for other lengths (although that hasn't
	# been observed) if they aren't null terminated.
	#

	theData.dsc$a_pointer[theData.dsc$w_length] = 0 ;

	XPUSHs(sv_2mortal(newSVpv(theData.dsc$a_pointer, theData.dsc$w_length)));
    }

    if (theStatus != RMS$_EOF)
    {
	if (! $VMS_STATUS_SUCCESS(theStatus))
	{
	    if (theDebug) printf ("Error [%08x] in lbr_get_module(%s) XS from lbr$get_record.\n",theStatus, key);
	    SETERRNO(EVMSERR, theStatus);
	    XSRETURN_EMPTY;
	}
    }
    
    SETERRNO(EVMSERR, theStatus) ;

    if (theDebug) printf ("Leaving lbr_get_module(%s) XS\n", key);

int
lbr_new (libname, function, type, theCreoptHash, libindex, debug)
    char * libname
    unsigned int function
    unsigned int type
    HV * theCreoptHash
    unsigned int libindex = NO_INIT
    int debug

  CODE:
    int theStatus = 0;
    int theDebug = 0;
    struct credef theCreopt ;

    dsc$descriptor_s libdsc = {0,DSC$K_DTYPE_T,DSC$K_CLASS_S,0};

    memset((void*) &theCreopt, 0, sizeof(theCreopt)) ;

    theCreopt.cre$l_type = getSvIVfromHV(theCreoptHash, "TYPE") ;
    theCreopt.cre$l_keylen = getSvIVfromHV(theCreoptHash, "KEYLEN") ;
    theCreopt.cre$l_alloc = getSvIVfromHV(theCreoptHash, "ALLOC") ;
    theCreopt.cre$l_idxmax = getSvIVfromHV(theCreoptHash, "IDXMAX") ;
    theCreopt.cre$l_uhdmax = getSvIVfromHV(theCreoptHash, "UHDMAX") ;
    theCreopt.cre$l_entall = getSvIVfromHV(theCreoptHash, "ENTALL") ;
    theCreopt.cre$l_luhmax = getSvIVfromHV(theCreoptHash, "LUHMAX") ;
    theCreopt.cre$l_vertyp = getSvIVfromHV(theCreoptHash, "VERTYP") ;
    theCreopt.cre$l_idxopt = getSvIVfromHV(theCreoptHash, "IDXOPT") ;

    libdsc.dsc$a_pointer = libname;
    libdsc.dsc$w_length = strlen(libname);

    theDebug = vlib_debug || (debug & 2);

    if (theDebug) printf ("In lbr_new XS for libname [%s], function [%d], type [%d]...\n", libname, function, type);

    theStatus = lbr$ini_control (&libindex, &function, &type);

    if (! $VMS_STATUS_SUCCESS(theStatus))
    {
	if (theDebug) printf ("Error [%08x] in lbr_new XS from lbr$ini_control.\n",theStatus);
	SETERRNO(EVMSERR,theStatus);
	XSRETURN_EMPTY ;
    }

    theStatus = lbr$open (&libindex, &libdsc, &theCreopt);

    if (theDebug) printf ("status of [%d] from lbr$open.\n", theStatus);

    if (! $VMS_STATUS_SUCCESS(theStatus))
    {
	if (theDebug) printf ("Error [%08x] in lbr_new XS from lbr$open.\n",theStatus);
	SETERRNO(EVMSERR,theStatus);
	XSRETURN_EMPTY ;
    }

    SETERRNO(EVMSERR, theStatus) ;

    RETVAL = 1;

  OUTPUT:
    libindex
    RETVAL

int
lbr_set_index (libindex, keyIndex, debug)
    int libindex
    int keyIndex 
    int debug

  CODE:
    long				i ;
    unsigned long			theStatus ;
    int					theDebug ;

    theDebug = vlib_debug || (debug & 2);
    if (theDebug) printf ("In lbr_set_index XS for key index [%d]...\n", keyIndex);

    theStatus = lbr$set_index(&libindex, &keyIndex);

    if (! $VMS_STATUS_SUCCESS(theStatus))
    {
	if (theDebug) printf ("Error [%08x] in lbr_set_index XS from lbr$set_index.\n",theStatus);
	SETERRNO(EVMSERR,theStatus);
	XSRETURN_EMPTY ;
    }

    SETERRNO(EVMSERR,theStatus);

    if (theDebug) printf ("Leaving lbr_set_index for key index [%d]\n", keyIndex);

    RETVAL = 1 ;
    
  OUTPUT:
    RETVAL
