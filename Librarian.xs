/*
 * The XS code for VMS::Librarian
 */

#include <lbrdef.h>
#include <string.h>
#include <stdio.h>
#include <ssdef.h>
#include <starlet.h>
#include <descrip.h>
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

extern unsigned int lbr$ini_control();
extern unsigned int lbr$open();
extern unsigned int lbr$lookup_key();
extern unsigned int lbr$set_module();
extern unsigned int lbr$close();
extern unsigned int lbr$get_record();

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

static int vlib_debug = 0;

static int
not_here(s)
char *s;
{
  croak("%s not implemented on this architecture", s);
  return -1;
}

static double
constant(name, arg)
char *name;
int arg;
{
  errno = 0;

  if (vlib_debug) printf ("In constant XS - name [%s]...\n",name);

  if (strEQ(name, "VLIB_CREATE")) return LBR$C_CREATE;
  if (strEQ(name, "VLIB_READ"))   return LBR$C_READ;
  if (strEQ(name, "VLIB_UPDATE")) return LBR$C_UPDATE;

  if (strEQ(name, "VLIB_OBJECT")) return LBR$C_TYP_OBJ;
  if (strEQ(name, "VLIB_MACRO"))  return LBR$C_TYP_MLB;
  if (strEQ(name, "VLIB_HELP"))   return LBR$C_TYP_HLP;
  if (strEQ(name, "VLIB_TEXT"))   return LBR$C_TYP_TXT;
  if (strEQ(name, "VLIB_IMAGE"))  return LBR$C_TYP_SHSTB;

  if (vlib_debug) printf ("Error in constant XS; name [%s] not found.\n",name);

  errno = EINVAL;
  return 0;
}

MODULE = VMS::Librarian		PACKAGE = VMS::Librarian		

int
_new (libname, function, type, libindex, debug)
  char * libname
  unsigned int function
  unsigned int type
  unsigned int libindex = NO_INIT
  int debug

  CODE:
  int status = 0;
  int tdebug = 0;

  struct dsc$descriptor_s libdsc = {0,DSC$K_DTYPE_T,DSC$K_CLASS_S,0};

  libdsc.dsc$a_pointer = libname;
  libdsc.dsc$w_length = strlen(libname);

  tdebug = vlib_debug || (debug & 2);
  if (tdebug) printf ("In _new XS for libname [%s]...\n", libname);

  status = lbr$ini_control (&libindex,
                            &function,
                            &type);

  if (tdebug) {
    printf("status of [%d] from lbr$ini_control.\n", status);
  }

  switch (status) {
    case SS$_NORMAL:
    case LBR$_NORMAL:
      printf ("libindex = [%8.8x] in _new XS from lbr$ini_control.\n",libindex);
      break;
    case LBR$_ILLFUNC:
    case LBR$_ILLTYP:
    case LBR$_TOOMNYLIB:
      if (tdebug) printf ("Error [%8.8x] in _new XS from lbr$ini_control;  returning undef.\n",status);
      SETERRNO(EVMSERR,status);
      XSRETURN_UNDEF;
      break;  /*  just making sure  */
    default:
        _ckvmssts(status);
  }

  status = lbr$open (&libindex,
                     &libdsc);

  if (tdebug) printf ("status of [%d] from lbr$open.\n", status);

  switch (status) {
    case SS$_NORMAL:
    case LBR$_NORMAL:
      printf ("Library [%s] opened ok in _new XS.\n",libname);
      break;
    case LBR$_ERRCLOSE:
    case LBR$_ILLCREOPT:
    case LBR$_ILLCTL:
    case LBR$_ILLFMT:
    case LBR$_ILLFUNC:
    case LBR$_LIBOPN:
    case LBR$_NOFILNAM:
    case LBR$_OLDLIBRARY:
    case LBR$_OLDMISMCH:
    case LBR$_TYPMISMCH:
      if (tdebug) printf ("Error [%8.8x] in _new XS from lbr$open;  returning undef.\n",status);
      SETERRNO(EVMSERR,status);
      XSRETURN_UNDEF;
      break;  /*  just making sure  */
    default:
        _ckvmssts(status);
  }

  RETVAL = 1;

  OUTPUT:
  libindex
  RETVAL

void
_get_module (libindex, key, debug)
  int libindex
  char * key
  int debug

  PPCODE:
  int k;
  int status;
  int tdebug;

  unsigned short txtrfa[3], retdsc[4];

  char buffer[2048];

  struct dsc$descriptor_s bufdsc = {0,DSC$K_DTYPE_T,DSC$K_CLASS_S,0};
  struct dsc$descriptor_s keydsc = {0,DSC$K_DTYPE_T,DSC$K_CLASS_S,0};

  bufdsc.dsc$a_pointer = buffer;
  bufdsc.dsc$w_length  = 2048;

  keydsc.dsc$a_pointer = key;
  keydsc.dsc$w_length = strlen(key);

  tdebug = vlib_debug || (debug & 2);
  if (tdebug) printf ("In _get_module XS for key [%s]...\n", key);

  status = lbr$lookup_key (&libindex, &keydsc, &txtrfa);

  switch (status) {
    case SS$_NORMAL:
    case LBR$_NORMAL:
      if (tdebug) printf ("Key of [%s] found in _get_module XS from lbr$lookup_key.\n", key);
      break;
    case LBR$_ILLCTL:
    case LBR$_INVRFA:
    case LBR$_KEYNOTFND:
    case LBR$_LIBNOTOPN:
      if (tdebug) printf ("Error [%8.8x] in _get_module XS from lbr$lookup_key;  returning undef.\n",status);
      SETERRNO(EVMSERR,status);
      XSRETURN_UNDEF;
      break;  /*  just making sure  */
    default:
      _ckvmssts(status);
  }

  while (SS$_NORMAL == (status = lbr$get_record (&libindex, &bufdsc, &retdsc))) {
    if (tdebug) printf ("[%3d] [%.*s]\n", retdsc[0], retdsc[0], buffer);
    if (retdsc[0] == 0) {
      retdsc[0] = 1;
      buffer[0] = 0;
    }
    XPUSHs(sv_2mortal(newSVpv(buffer, retdsc[0])));
  }

  switch (status) {
    case RMS$_EOF:  /* the expected results */
      break;
    case LBR$_ILLCTL:
    case LBR$_LIBNOTOPN:
    case LBR$_LKPNOTDON:
      if (tdebug) printf ("Error [%8.8x] in _get_module XS from lbr$get_record.\n",status);
      SETERRNO(EVMSERR,status);
      break;  /*  just making sure  */
    default:
      _ckvmssts(status);
  }

  if (tdebug) printf ("Leaving _get_module for key [%s]\n", key);

double
constant(name,arg)
	char *		name
	int		arg

