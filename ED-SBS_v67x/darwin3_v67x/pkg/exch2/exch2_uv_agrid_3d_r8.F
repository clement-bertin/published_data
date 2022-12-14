#include "CPP_EEOPTIONS.h"
#include "W2_OPTIONS.h"

CBOP
C     !ROUTINE: EXCH2_UV_AGRID_3D_R8

C     !INTERFACE:
      SUBROUTINE EXCH2_UV_AGRID_3D_R8(
     U                                 uPhi, vPhi,
     I                                 withSigns, myNz, myThid )

C     !DESCRIPTION:
C*=====================================================================*
C  Purpose: SUBROUTINE EXCH2_UV_AGRID_3D_R8
C      handle exchanges for a 3D vector field on an A-grid.
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
C  Calls: exch_R8 (exch2_R81_cube) - for each component
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
      _R8 uPhi(1-OLx:sNx+OLx,1-OLy:sNy+OLy,myNz,nSx,nSy)
      _R8 vPhi(1-OLx:sNx+OLx,1-OLy:sNy+OLy,myNz,nSx,nSy)
      LOGICAL withSigns
      INTEGER myThid

C     !LOCAL VARIABLES:
C     == Local variables ==
C     i,j,k,bi,bj   :: loop indices.
C     OL[wens]      :: Overlap extents in west, east, north, south.
C     exchWidth[XY] :: Extent of regions that will be exchanged.
C     uLoc,vLoc     :: copies of the vector components with haloes filled.

      INTEGER i,j,k,bi,bj
      INTEGER OLw, OLe, OLn, OLs, exchWidthX, exchWidthY
      _R8 uLoc(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _R8 vLoc(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _R8 negOne
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

C--   First call the exchanges for the two components

       CALL EXCH2_R81_CUBE( uPhi, .FALSE., 'T ',
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_IGNORE_CORNERS, myThid )
       CALL EXCH2_R81_CUBE( uPhi, .FALSE., 'T ',
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )

       CALL EXCH2_R81_CUBE( vPhi, .FALSE., 'T ',
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_IGNORE_CORNERS, myThid )
       CALL EXCH2_R81_CUBE( vPhi, .FALSE., 'T ',
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )

C- note: can substitute the low-level S/R calls above with:
c      CALL EXCH2_3D_R8( uPhi, myNz, myThid )
c      CALL EXCH2_3D_R8( vPhi, myNz, myThid )

      IF ( useCubedSphereExchange ) THEN

C--   Then we may need to switch u and v components
C     and/or the signs depending on which cube face we are located.

C--   Loops on tile indices:
       DO bj = myByLo(myThid), myByHi(myThid)
        DO bi = myBxLo(myThid), myBxHi(myThid)

C-    Choose what to do at each edge of the halo based on which face we are
         myTile = W2_myTileList(bi,bj)
         myFace = exch2_myFace(myTile)

C--   Loops on level index:
         DO k = 1,myNz

C-    First we copy the component info into local dummy arrays
          DO j = 1-OLy,sNy+OLy
           DO i = 1-OLx,sNx+OLx
             uLoc(i,j) = uPhi(i,j,k,bi,bj)
             vLoc(i,j) = vPhi(i,j,k,bi,bj)
           ENDDO
          ENDDO

C-    odd faces share disposition of all sections of the halo
          IF ( MOD(myFace,2).EQ.1 ) THEN
C-    North:
           IF (exch2_isNedge(myTile).EQ.1) THEN
             DO j = 1,exchWidthY
              DO i = 1-OLx,sNx+OLx
               uPhi(i,sNy+j,k,bi,bj) = vLoc(i,sNy+j)*negOne
               vPhi(i,sNy+j,k,bi,bj) = uLoc(i,sNy+j)
              ENDDO
             ENDDO
           ENDIF
C-    South: (nothing to change)
c          IF (exch2_isSedge(myTile).EQ.1) THEN
c            DO j = 1,exchWidthY
c             DO i = 1-OLx,sNx+OLx
c              uPhi(i,1-j,k,bi,bj) = uLoc(i,1-j)
c              vPhi(i,1-j,k,bi,bj) = vLoc(i,1-j)
c             ENDDO
c            ENDDO
c          ENDIF
C-    East: (nothing to change)
c          IF (exch2_isEedge(myTile).EQ.1) THEN
c            DO j = 1-OLy,sNy+OLy
c             DO i = 1,exchWidthX
c              uPhi(sNx+i,j,k,bi,bj) = uLoc(sNx+i,j)
c              vPhi(sNx+i,j,k,bi,bj) = vLoc(sNx+i,j)
c             ENDDO
c            ENDDO
c          ENDIF
C-    West:
           IF (exch2_isWedge(myTile).EQ.1) THEN
             DO j = 1-OLy,sNy+OLy
              DO i = 1,exchWidthX
               uPhi(1-i,j,k,bi,bj) = vLoc(1-i,j)
               vPhi(1-i,j,k,bi,bj) = uLoc(1-i,j)*negOne
              ENDDO
             ENDDO
           ENDIF

          ELSE
C-    Now the even faces (share disposition of all sections of the halo)

C-    East:
           IF (exch2_isEedge(myTile).EQ.1) THEN
             DO j = 1-OLy,sNy+OLy
              DO i = 1,exchWidthX
               uPhi(sNx+i,j,k,bi,bj) = vLoc(sNx+i,j)
               vPhi(sNx+i,j,k,bi,bj) = uLoc(sNx+i,j)*negOne
              ENDDO
             ENDDO
           ENDIF
C-    West: (nothing to change)
c          IF (exch2_isWedge(myTile).EQ.1) THEN
c            DO j = 1-OLy,sNy+OLy
c             DO i = 1,exchWidthX
c              uPhi(1-i,j,k,bi,bj) = uLoc(1-i,j)
c              vPhi(1-i,j,k,bi,bj) = vLoc(1-i,j)
c             ENDDO
c            ENDDO
c          ENDIF
C-    North: (nothing to change)
c          IF (exch2_isNedge(myTile).EQ.1) THEN
c            DO j = 1,exchWidthY
c             DO i = 1-OLx,sNx+OLx
c              uPhi(i,sNy+j,k,bi,bj) = uLoc(i,sNy+j)
c              vPhi(i,sNy+j,k,bi,bj) = vLoc(i,sNy+j)
c             ENDDO
c            ENDDO
c          ENDIF
C-    South:
           IF (exch2_isSedge(myTile).EQ.1) THEN
             DO j = 1,exchWidthY
              DO i = 1-OLx,sNx+OLx
               uPhi(i,1-j,k,bi,bj) = vLoc(i,1-j)*negOne
               vPhi(i,1-j,k,bi,bj) = uLoc(i,1-j)
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
