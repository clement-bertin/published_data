#include "PACKAGES_CONFIG.h"
#include "CPP_EEOPTIONS.h"

CBOP
C     !ROUTINE: EXCH_SM_3D_R4

C     !INTERFACE:
      SUBROUTINE EXCH_SM_3D_R4(
     U                                phi,
     I                                withSigns, myNz, myThid )

C     !DESCRIPTION:
C*=====================================================================*
C  Purpose: SUBROUTINE EXCH_SM_3D_R4
C      handle exchanges for Second Moment (Sxy) 3D field
C     (for quantity which Sign depend on X & Y orientation), at Mass point
C
C  Input:
C    phi(lon,lat,levs,bi,bj)  :: array with overlap regions are to be exchanged
C    withSigns (logical)      :: true to use signs of X & Y orientation
C    myNz                     :: 3rd dimension of input arrays phi
C    myThid                   :: my Thread Id number
C
C  Output: phi is updated (halo regions filled)
C
C  Calls: exch (either exch_rx_cube or exch_rx)
C
C  NOTES: 1) If using CubedSphereExchange, only works on ONE PROCESSOR!
C*=====================================================================*

C     !USES:
      IMPLICIT NONE

#include "SIZE.h"
#include "EEPARAMS.h"

C     !INPUT/OUTPUT PARAMETERS:
C     == Argument list variables ==
      INTEGER myNz
      _R4 phi(1-OLx:sNx+OLx,1-OLy:sNy+OLy,myNz,nSx,nSy)
      LOGICAL withSigns
      INTEGER myThid

C     !LOCAL VARIABLES:
#ifndef ALLOW_EXCH2
C     == Local variables ==
C     i,j,k,bi,bj   :: loop indices.
C     OL[wens]      :: Overlap extents in west, east, north, south.
C     exchWidth[XY] :: Extent of regions that will be exchanged.
C     dummy[12]     :: copies of the vector components with haloes filled.

      INTEGER i,j,k,bi,bj
      INTEGER OLw, OLe, OLn, OLs, exchWidthX, exchWidthY
      _R4 negOne
#endif
CEOP

#ifdef ALLOW_EXCH2
      CALL EXCH2_SM_3D_R4(
     U                     phi,
     I                     withSigns, myNz, myThid )
#else /* ALLOW_EXCH2 */

      OLw        = OLx
      OLe        = OLx
      OLn        = OLy
      OLs        = OLy
      exchWidthX = OLx
      exchWidthY = OLy
      negOne = 1.

      IF (useCubedSphereExchange) THEN
C---  using CubedSphereExchange:

C--   First call the exchanges

       CALL EXCH1_R4_CUBE( phi, .FALSE.,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )

       IF (withSigns) THEN
C--   Then we may need to switch the signs depending on which cube face
C      we are located (we assume that bj is always=1).
C     Choose what to do at each edge of the halo based on which face
        negOne = -1.

C--   Loops on tile and level indices:
        DO bj = myByLo(myThid), myByHi(myThid)
        DO bi = myBxLo(myThid), myBxHi(myThid)
         DO k = 1,myNz

C-    odd (or even) faces share disposition of all sections of the halo
          IF ( MOD(bi,2).EQ.1 ) THEN
C--   Face 1,3,5:

           DO j = 1,exchWidthY
            DO i = 1,sNx
C-    North:
             phi(i,sNy+j,k,bi,bj) = phi(i,sNy+j,k,bi,bj)*negOne
C-    South: (nothing to change)
c            phi(i,1-j,k,bi,bj) = phi(i,1-j,k,bi,bj)
            ENDDO
           ENDDO
           DO j = 1,sNy
            DO i = 1,exchWidthX
C-    East: (nothing to change)
c            phi(sNx+i,j,k,bi,bj) = phi(sNx+i,j,k,bi,bj)
C-    West:
             phi(1-i,j,k,bi,bj) = phi(1-i,j,k,bi,bj)*negOne
            ENDDO
           ENDDO

          ELSE
C--   Face 2,4,6:

           DO j = 1,sNy
            DO i = 1,exchWidthX
C-    East:
             phi(sNx+i,j,k,bi,bj) = phi(sNx+i,j,k,bi,bj)*negOne
C-    West: (nothing to change)
c            phi(1-i,j,k,bi,bj) = phi(1-i,j,k,bi,bj)
            ENDDO
           ENDDO
           DO j = 1,exchWidthY
            DO i = 1,sNx
C-    North: (nothing to change)
c            phi(i,sNy+j,k,bi,bj) = phi(i,sNy+j,k,bi,bj)
C-    South:
             phi(i,1-j,k,bi,bj) = phi(i,1-j,k,bi,bj)*negOne
            ENDDO
           ENDDO

C--   End odd / even faces
          ENDIF

C--   end of Loops on tile and level indices (k,bi,bj).
         ENDDO
        ENDDO
        ENDDO

C--   End withSigns
       ENDIF

      ELSE
C---  not using CubedSphereExchange:

#ifdef DISCONNECTED_TILES
       CALL EXCH0_R4( phi,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )
#else /* DISCONNECTED_TILES */
       CALL EXCH1_R4( phi,
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
