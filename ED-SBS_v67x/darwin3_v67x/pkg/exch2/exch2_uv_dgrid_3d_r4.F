#include "CPP_EEOPTIONS.h"
#include "W2_OPTIONS.h"

CBOP
C     !ROUTINE: EXCH2_UV_DGRID_3D_R4

C     !INTERFACE:
      SUBROUTINE EXCH2_UV_DGRID_3D_R4(
     U                                 uPhi, vPhi,
     I                                 withSigns, myNz, myThid )

C     !DESCRIPTION:
C*=====================================================================*
C  Purpose: SUBROUTINE EXCH2_UV_DGRID_3D_R4
C      handle exchanges for a 3D vector field on an D-grid.
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
C  Calls: EXCH_R4 (EXCH2_R42_CUBE) ignoring sign
C         then put back the right signs
C
C*=====================================================================*

C     !USES:
      IMPLICIT NONE

#include "SIZE.h"
#include "EEPARAMS.h"
#include "W2_EXCH2_SIZE.h"
#include "W2_EXCH2_TOPOLOGY.h"

C     !INPUT/OUTPUT PARAMETERS:
C     == Argument list variables ==
      INTEGER myNz
      _R4 uPhi(1-OLx:sNx+OLx,1-OLy:sNy+OLy,myNz,nSx,nSy)
      _R4 vPhi(1-OLx:sNx+OLx,1-OLy:sNy+OLy,myNz,nSx,nSy)
      LOGICAL withSigns
      INTEGER myThid

C     !LOCAL VARIABLES:
C     == Local variables ==
C     i,j,k,bi,bj   :: loop indices.
C     OL[wens]      :: Overlap extents in west, east, north, south.
C     exchWidth[XY] :: Extent of regions that will be exchanged.

      INTEGER i,j,k,bi,bj
      INTEGER OLw, OLe, OLn, OLs, exchWidthX, exchWidthY
      _R4 negOne
      INTEGER myTile, myFace
CEOP

      OLw        = OLx
      OLe        = OLx
      OLn        = OLy
      OLs        = OLy
      exchWidthX = OLx
      exchWidthY = OLy
      negOne = 1.
      IF (withSigns) negOne = -1.

C--   First call the exchanges for the two components, ignoring the Sign
C     note the order: vPhi,uPhi on D-grid are co-located with (u,v)_Cgrid

c      CALL EXCH2_R42_CUBE( vPhi, uPhi, .FALSE., 'Cg',
c    I            OLw, OLe, OLs, OLn, myNz,
c    I            exchWidthX, exchWidthY,
c    I            EXCH_UPDATE_CORNERS, myThid )
c      CALL EXCH2_R42_CUBE( vPhi, uPhi, .FALSE., 'Cg',
c    I            OLw, OLe, OLs, OLn, myNz,
c    I            exchWidthX, exchWidthY,
c    I            EXCH_UPDATE_CORNERS, myThid )

C- note: can substitute the low-level S/R calls above with:
#ifdef W2_USE_R1_ONLY
      CALL EXCH2_UV_CGRID_3D_R4(
     U                     vPhi, uPhi,
     I                     .FALSE., myNz, myThid )
#else
      CALL EXCH2_UV_3D_R4(
     U                     vPhi, uPhi,
     I                     .FALSE., myNz, myThid )
#endif

      IF ( useCubedSphereExchange ) THEN
C---  using CubedSphereExchange:

C--   Then we may need to switch the signs depending on which cube face
C     we are located.

C--   Loops on tile indices:
       DO bj = myByLo(myThid), myByHi(myThid)
        DO bi = myBxLo(myThid), myBxHi(myThid)

C-    Choose what to do at each edge of the halo based on which face we are
         myTile = W2_myTileList(bi,bj)
         myFace = exch2_myFace(myTile)

C--   Loops on level index:
         DO k = 1,myNz

C-    odd faces share disposition of all sections of the halo
          IF ( MOD(myFace,2).EQ.1 ) THEN
C-    North:
           IF (exch2_isNedge(myTile).EQ.1) THEN
             DO j = 1,exchWidthY
              DO i = 1-OLx,sNx+OLx
               uPhi(i,sNy+j,k,bi,bj) = uPhi(i,sNy+j,k,bi,bj)*negOne
c              vPhi(i,sNy+j,k,bi,bj) = vPhi(i,sNy+j,k,bi,bj)
              ENDDO
             ENDDO
           ENDIF
C-    South: (nothing to change)
c          IF (exch2_isSedge(myTile).EQ.1) THEN
c            DO j = 1,exchWidthY
c             DO i = 1-OLx,sNx+OLx
c              uPhi(i,1-j,k,bi,bj) = uPhi(i,1-j,k,bi,bj)
c              vPhi(i,1-j,k,bi,bj) = vPhi(i,1-j,k,bi,bj)
c             ENDDO
c            ENDDO
c          ENDIF
C-    East: (nothing to change)
c          IF (exch2_isEedge(myTile).EQ.1) THEN
c            DO j = 1-OLy,sNy+OLy
c             DO i = 1,exchWidthX
c              uPhi(sNx+i,j,k,bi,bj) = uPhi(sNx+i,j,k,bi,bj)
c              vPhi(sNx+i,j,k,bi,bj) = vPhi(sNx+i,j,k,bi,bj)
c             ENDDO
c            ENDDO
c          ENDIF
C-    West:
           IF (exch2_isWedge(myTile).EQ.1) THEN
             DO j = 1-OLy,sNy+OLy
              DO i = 1,exchWidthX
c              uPhi(1-i,j,k,bi,bj) = uPhi(1-i,j,k,bi,bj)
               vPhi(1-i,j,k,bi,bj) = vPhi(1-i,j,k,bi,bj)*negOne
              ENDDO
             ENDDO
           ENDIF

          ELSE
C-    Now the even faces (share disposition of all sections of the halo)

C-    East:
           IF (exch2_isEedge(myTile).EQ.1) THEN
             DO j = 1-OLy,sNy+OLy
              DO i = 1,exchWidthX
c              uPhi(sNx+i,j,k,bi,bj) = uPhi(sNx+i,j,k,bi,bj)
               vPhi(sNx+i,j,k,bi,bj) = vPhi(sNx+i,j,k,bi,bj)*negOne
              ENDDO
             ENDDO
           ENDIF
C-    West: (nothing to change)
c          IF (exch2_isWedge(myTile).EQ.1) THEN
c            DO j = 1-OLy,sNy+OLy
c             DO i = 1,exchWidthX
c              uPhi(1-i,j,k,bi,bj) = uPhi(1-i,j,k,bi,bj)
c              vPhi(1-i,j,k,bi,bj) = vPhi(1-i,j,k,bi,bj)
c             ENDDO
c            ENDDO
c          ENDIF
C-    North: (nothing to change)
c          IF (exch2_isNedge(myTile).EQ.1) THEN
c            DO j = 1,exchWidthY
c             DO i = 1-OLx,sNx+OLx
c              uPhi(i,sNy+j,k,bi,bj) = uPhi(i,sNy+j,k,bi,bj)
c              vPhi(i,sNy+j,k,bi,bj) = vPhi(i,sNy+j,k,bi,bj)
c             ENDDO
c            ENDDO
c          ENDIF
C-    South:
           IF (exch2_isSedge(myTile).EQ.1) THEN
             DO j = 1,exchWidthY
              DO i = 1-OLx,sNx+OLx
               uPhi(i,1-j,k,bi,bj) = uPhi(i,1-j,k,bi,bj)*negOne
c              vPhi(i,1-j,k,bi,bj) = vPhi(i,1-j,k,bi,bj)
              ENDDO
             ENDDO
           ENDIF

C end odd / even faces
          ENDIF

C--    end of Loops on tile and level indices (k,bi,bj).
         ENDDO
        ENDDO
       ENDDO

C---  using or not using CubedSphereExchange: end
      ENDIF

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

CEH3 ;;; Local Variables: ***
CEH3 ;;; mode:fortran ***
CEH3 ;;; End: ***
