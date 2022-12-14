#include "PACKAGES_CONFIG.h"
#include "CPP_EEOPTIONS.h"

CBOP
C     !ROUTINE: EXCH_UV_BGRID_3D_R8

C     !INTERFACE:
      SUBROUTINE EXCH_UV_BGRID_3D_R8(
     U                                 uPhi, vPhi,
     I                                 withSigns, myNz, myThid )

C     !DESCRIPTION:
C*=====================================================================*
C  Purpose: SUBROUTINE EXCH_UV_BGRID_3D_R8
C      handle exchanges for a 3D vector field on an B-grid.
C
C  Input:
C    uPhi(lon,lat,levs,bi,bj) :: first component of vector
C    vPhi(lon,lat,levs,bi,bj) :: second component of vector
C    withSigns (logical)      :: true to use sign of components
C    myNz                     :: 3rd dimension of input arrays uPhi,vPhi
C    myThid                   :: my Thread Id number
C
C  Output: uPhi and vPhi are updated (halo regions filled)
C
C  Branch to appropriate exchange routine for B-grid vector field
C*=====================================================================*

C     !USES:
      IMPLICIT NONE

#include "SIZE.h"
#include "EEPARAMS.h"

C     !INPUT/OUTPUT PARAMETERS:
C     == Argument list variables ==
      INTEGER myNz
      _R8 uPhi(1-OLx:sNx+OLx,1-OLy:sNy+OLy,myNz,nSx,nSy)
      _R8 vPhi(1-OLx:sNx+OLx,1-OLy:sNy+OLy,myNz,nSx,nSy)
      LOGICAL withSigns
      INTEGER myThid

C     !LOCAL VARIABLES:
#ifndef ALLOW_EXCH2
C     == Local variables ==
C     OL[wens]      :: Overlap extents in west, east, north, south.
C     exchWidth[XY] :: Extent of regions that will be exchanged.

      INTEGER OLw, OLe, OLn, OLs, exchWidthX, exchWidthY
#endif
CEOP

#ifdef ALLOW_EXCH2
      CALL EXCH2_UV_BGRID_3D_R8(
     U                       uPhi, vPhi,
     I                       withSigns, myNz, myThid )
#else /* ALLOW_EXCH2 */
      OLw        = OLx
      OLe        = OLx
      OLn        = OLy
      OLs        = OLy
      exchWidthX = OLx
      exchWidthY = OLy

      IF ( useCubedSphereExchange ) THEN
C---  using CubedSphereExchange:

       CALL EXCH1_BG_R8_CUBE(
     U            uPhi, vPhi,
     I            withSigns,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )

      ELSE
C---  not using CubedSphereExchange:

#ifdef DISCONNECTED_TILES
       CALL EXCH0_R8( uPhi,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )
       CALL EXCH0_R8( vPhi,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )
#else /* DISCONNECTED_TILES */
       CALL EXCH1_R8( uPhi,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )
       CALL EXCH1_R8( vPhi,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )
#endif /* DISCONNECTED_TILES */

C---  using or not using CubedSphereExchange: end
      ENDIF

#endif /* ALLOW_EXCH2 */

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

CEH3 ;;; Local Variables: ***
CEH3 ;;; mode:fortran ***
CEH3 ;;; End: ***
