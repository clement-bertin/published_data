#include "PACKAGES_CONFIG.h"
#include "CPP_EEOPTIONS.h"

CBOP
C     !ROUTINE: EXCH_XYZ_R8

C     !INTERFACE:
      SUBROUTINE EXCH_XYZ_R8(
     U                       phi,
     I                       myThid )

C     !DESCRIPTION:
C     *==========================================================*
C     | SUBROUTINE EXCH_XYZ_R8
C     | o Handle exchanges for _R8, three-dim scalar arrays.
C     *==========================================================*
C     | Invoke appropriate exchange routine depending on type
C     | of grid (cube or globally indexed) to be operated on.
C     *==========================================================*

C     !USES:
      IMPLICIT NONE

C     === Global data ===
#include "SIZE.h"
#include "EEPARAMS.h"

C     !INPUT/OUTPUT PARAMETERS:
C     === Routine arguments ===
C     phi    :: Array with overlap regions are to be exchanged
C     myThid :: My thread id.
      _R8 phi(1-OLx:sNx+OLx,1-OLy:sNy+OLy,1:Nr,nSx,nSy)
      INTEGER myThid

C     !LOCAL VARIABLES:
#ifndef ALLOW_EXCH2
C     == Local variables ==
C     OL[wens]       :: Overlap extents in west, east, north, south.
C     exchWidth[XY]  :: Extent of regions that will be exchanged.
      INTEGER OLw, OLe, OLn, OLs, exchWidthX, exchWidthY, myNz
#endif
CEOP

#ifdef ALLOW_EXCH2
      CALL EXCH2_3D_R8( phi, Nr, myThid )
#else /* ALLOW_EXCH2 */

      OLw        = OLx
      OLe        = OLx
      OLn        = OLy
      OLs        = OLy
      exchWidthX = OLx
      exchWidthY = OLy
      myNz       = Nr
      IF (useCubedSphereExchange) THEN
       CALL EXCH1_R8_CUBE( phi, .FALSE.,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )
      ELSE
#ifdef DISCONNECTED_TILES
       CALL EXCH0_R8( phi,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )
#else /* DISCONNECTED_TILES */
       CALL EXCH1_R8( phi,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )
#endif /* DISCONNECTED_TILES */
      ENDIF

#endif /* ALLOW_EXCH2 */

      RETURN
      END
