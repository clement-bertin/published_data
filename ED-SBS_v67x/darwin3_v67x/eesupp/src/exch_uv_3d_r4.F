#include "PACKAGES_CONFIG.h"
#include "CPP_EEOPTIONS.h"
#ifdef ALLOW_EXCH2
#include "W2_OPTIONS.h"
#endif

CBOP
C     !ROUTINE: EXCH_UV_3D_R4

C     !INTERFACE:
      SUBROUTINE EXCH_UV_3D_R4(
     U                          uPhi, vPhi,
     I                          withSigns, myNz, myThid )

C     !DESCRIPTION:
C     *==========================================================*
C     | SUBROUTINE EXCH_UV_3D_R4
C     | o Handle exchanges for _R4, 3-dimensional vector arrays.
C     *==========================================================*
C     | Vector arrays need to be rotated and interchaged for
C     | exchange operations on some grids. This driver routine
C     | branches to support this.
C     *==========================================================*

C     !USES:
      IMPLICIT NONE

C     === Global data ===
#include "SIZE.h"
#include "EEPARAMS.h"

C     !INPUT/OUTPUT PARAMETERS:
C     === Routine arguments ===
C     uPhi      :: 2 components of a vector field with overlap regions
C     vPhi      :: to be exchanged
C     withSigns :: Flag controlling whether vector is signed.
C     myNz      :: 3rd dimension of array to exchange
C     myThid    :: my Thread Id. number
      INTEGER myNz
      _R4 uPhi(1-OLx:sNx+OLx,1-OLy:sNy+OLy,myNz,nSx,nSy)
      _R4 vPhi(1-OLx:sNx+OLx,1-OLy:sNy+OLy,myNz,nSx,nSy)
      LOGICAL withSigns
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
#ifdef W2_USE_R1_ONLY
      CALL EXCH2_UV_CGRID_3D_R4(
     U                     uPhi, vPhi,
     I                     withSigns, myNz, myThid )
#else
      CALL EXCH2_UV_3D_R4(
     U                     uPhi, vPhi,
     I                     withSigns, myNz, myThid )
#endif
#else /* ALLOW_EXCH2 */

      OLw        = OLx
      OLe        = OLx
      OLn        = OLy
      OLs        = OLy
      exchWidthX = OLx
      exchWidthY = OLy
      IF (useCubedSphereExchange) THEN
       CALL EXCH1_UV_R4_CUBE( uPhi, vPhi, withSigns,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )
      ELSE
#ifdef DISCONNECTED_TILES
       CALL EXCH0_R4( uPhi,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )
       CALL EXCH0_R4( vPhi,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )
#else /* DISCONNECTED_TILES */
       CALL EXCH1_R4( uPhi,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )
       CALL EXCH1_R4( vPhi,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )
#endif /* DISCONNECTED_TILES */
      ENDIF

#endif /* ALLOW_EXCH2 */

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

CEH3 ;;; Local Variables: ***
CEH3 ;;; mode:fortran ***
CEH3 ;;; End: ***
