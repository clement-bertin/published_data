#include "CPP_EEOPTIONS.h"
#include "W2_OPTIONS.h"

CBOP
C     !ROUTINE: EXCH2_SM_3D_RS

C     !INTERFACE:
      SUBROUTINE EXCH2_SM_3D_RS(
     U                           phi,
     I                           withSigns, myNz, myThid )

C     !DESCRIPTION:
C*=====================================================================*
C  Purpose: SUBROUTINE EXCH2_SM_3D_RS
C      handle exchanges for Second Moment (Sxy) 3D field
C     (for quantity which Sign depend on X & Y orientation), at Mass point
C
C  Input:
C    phi(lon,lat,levs,bi,bj)  :: array with overlap regions are to be exchanged
C    withSigns (logical)      :: true to use sign of components
C    myNz                     :: 3rd dimension of input arrays uPhi,vPhi
C    myThid                   :: my Thread Id number
C
C  Output: phi is updated (halo regions filled)
C
C  Calls: exch_RS (exch2_RS1_cube)
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
      _RS phi(1-OLx:sNx+OLx,1-OLy:sNy+OLy,myNz,nSx,nSy)
      LOGICAL withSigns
      INTEGER myThid

C     !LOCAL VARIABLES:
C     == Local variables ==
C     i,j,k,bi,bj   :: loop indices.
C     OL[wens]      :: Overlap extents in west, east, north, south.
C     exchWidth[XY] :: Extent of regions that will be exchanged.

      INTEGER i,j,k,bi,bj
      INTEGER OLw, OLe, OLn, OLs, exchWidthX, exchWidthY
      _RS negOne
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

C--   First call the exchanges

       CALL EXCH2_RS1_CUBE( phi, .FALSE., 'T ',
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_IGNORE_CORNERS, myThid )
       CALL EXCH2_RS1_CUBE( phi, .FALSE., 'T ',
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )

C- note: can substitute the low-level S/R call above with:
c      CALL EXCH2_3D_RS( phi, myNz, myThid )

      IF ( useCubedSphereExchange .AND. withSigns ) THEN
C---  using CubedSphereExchange with Signs:

C--   Then we may need to switch the signs depending on which cube face
C     we are located.

C--   Loops on tile indices:
       DO bj = myByLo(myThid), myByHi(myThid)
        DO bi = myBxLo(myThid), myBxHi(myThid)

C     Choose what to do at each edge of the halo based on which face we are
         myTile = W2_myTileList(bi,bj)
         myFace = exch2_myFace(myTile)

C--   Loops on level index:
         DO k = 1,myNz

C-    odd (or even) faces share disposition of all sections of the halo
          IF ( MOD(myFace,2).EQ.1 ) THEN
C--   Face 1,3,5:

C-    North:
           IF (exch2_isNedge(myTile).EQ.1) THEN
             DO j = 1,exchWidthY
              DO i = 1-OLx,sNx+OLx
               phi(i,sNy+j,k,bi,bj) = phi(i,sNy+j,k,bi,bj)*negOne
              ENDDO
             ENDDO
           ENDIF
C-    South: (nothing to change)
c          IF (exch2_isSedge(myTile).EQ.1) THEN
c            DO j = 1,exchWidthY
c             DO i = 1-OLx,sNx+OLx
c              phi(i,1-j,k,bi,bj) = phi(i,1-j,k,bi,bj)
c             ENDDO
c            ENDDO
c          ENDIF
C-    East: (nothing to change)
c          IF (exch2_isEedge(myTile).EQ.1) THEN
c            DO j = 1-OLy,sNy+OLy
c             DO i = 1,exchWidthX
c              phi(sNx+i,j,k,bi,bj) = phi(sNx+i,j,k,bi,bj)
c             ENDDO
c            ENDDO
c          ENDIF
C-    West:
           IF (exch2_isWedge(myTile).EQ.1) THEN
             DO j = 1-OLy,sNy+OLy
              DO i = 1,exchWidthX
               phi(1-i,j,k,bi,bj) = phi(1-i,j,k,bi,bj)*negOne
              ENDDO
             ENDDO
           ENDIF

          ELSE
C--   Face 2,4,6:

C-    East:
           IF (exch2_isEedge(myTile).EQ.1) THEN
             DO j = 1-OLy,sNy+OLy
              DO i = 1,exchWidthX
               phi(sNx+i,j,k,bi,bj) = phi(sNx+i,j,k,bi,bj)*negOne
              ENDDO
             ENDDO
           ENDIF
C-    West: (nothing to change)
c          IF (exch2_isWedge(myTile).EQ.1) THEN
c            DO j = 1-OLy,sNy+OLy
c             DO i = 1,exchWidthX
c              phi(1-i,j,k,bi,bj) = phi(1-i,j,k,bi,bj)
c             ENDDO
c            ENDDO
c          ENDIF
C-    North: (nothing to change)
c          IF (exch2_isNedge(myTile).EQ.1) THEN
c            DO j = 1,exchWidthY
c             DO i = 1-OLx,sNx+OLx
c              phi(i,sNy+j,k,bi,bj) = phi(i,sNy+j,k,bi,bj)
c             ENDDO
c            ENDDO
c          ENDIF
C-    South:
           IF (exch2_isSedge(myTile).EQ.1) THEN
             DO j = 1,exchWidthY
              DO i = 1-OLx,sNx+OLx
               phi(i,1-j,k,bi,bj) = phi(i,1-j,k,bi,bj)*negOne
              ENDDO
             ENDDO
           ENDIF

C--   End odd / even faces
          ENDIF

C--    end of Loops on tile and level indices (k,bi,bj).
         ENDDO
        ENDDO
       ENDDO

C---  using or not using CubedSphereExchange with Signs: end
      ENDIF

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

CEH3 ;;; Local Variables: ***
CEH3 ;;; mode:fortran ***
CEH3 ;;; End: ***
