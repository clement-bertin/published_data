#include "PACKAGES_CONFIG.h"
#include "CPP_EEOPTIONS.h"

CBOP
C     !ROUTINE: EXCH_Z_3D_RS

C     !INTERFACE:
      SUBROUTINE EXCH_Z_3D_RS(
     U                         phi,
     I                         myNz, myThid )
      IMPLICIT NONE
C     !DESCRIPTION:
C     *==========================================================*
C     | SUBROUTINE EXCH_Z_3D_RS
C     | o Handle exchanges for _RS, 3-dim, zeta coord arrays.
C     *==========================================================*
C     | Branch to appropriate exchange routine for a zeta coord
C     | array on the current grid scheme.
C     *==========================================================*

C     !USES:
C     == Global variables ==
#include "SIZE.h"
#include "EEPARAMS.h"

C     !INPUT/OUTPUT PARAMETERS:
C     == Routine arguments ==
C     phi    :: Array with overlap regions are to be exchanged
C               Note - The interface to EXCH_RS assumes that
C               the standard Fortran 77 sequence association rules
C               apply.
C     myNz   :: 3rd dimension of array to exchange
C     myThid :: My thread id.
      INTEGER myNz
      _RS phi(1-OLx:sNx+OLx,1-OLy:sNy+OLy,myNz,nSx,nSy)
      INTEGER myThid

C     !LOCAL VARIABLES:
#ifndef ALLOW_EXCH2
C     == Local variables ==
C     OL[wens]       :: Overlap extents in west, east, north, south.
C     exchWidth[XY]  :: Extent of regions that will be exchanged.
      INTEGER OLw, OLe, OLn, OLs, exchWidthX, exchWidthY
#endif
CEOP

#ifdef ALLOW_EXCH2
      CALL EXCH2_Z_3D_RS(
     U                    phi,
     I                    myNz, myThid )
#else /* ALLOW_EXCH2 */

      OLw        = OLx
      OLe        = OLx
      OLn        = OLy
      OLs        = OLy
      exchWidthX = OLx
      exchWidthY = OLy
      IF (useCubedSphereExchange) THEN
       CALL EXCH1_Z_RS_CUBE( phi, .FALSE.,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )
      ELSE
#ifdef DISCONNECTED_TILES
       CALL EXCH0_RS( phi,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )
#else /* DISCONNECTED_TILES */
       CALL EXCH1_RS( phi,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )
#endif /* DISCONNECTED_TILES */
      ENDIF

#endif /* ALLOW_EXCH2 */

      RETURN
      END
