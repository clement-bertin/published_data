#include "CPP_EEOPTIONS.h"
#include "W2_OPTIONS.h"

CBOP
C     !ROUTINE: EXCH2_3D_R8

C     !INTERFACE:
      SUBROUTINE EXCH2_3D_R8(
     U                       phi,
     I                       myNz, myThid )

C     !DESCRIPTION:
C     *==========================================================*
C     | SUBROUTINE EXCH2_3D_R8
C     | o Handle exchanges for _R8, three-dim scalar arrays.
C     *==========================================================*

C     !USES:
      IMPLICIT NONE
C     === Global data ===
#include "SIZE.h"
#include "EEPARAMS.h"
#include "W2_EXCH2_SIZE.h"
#include "W2_EXCH2_TOPOLOGY.h"
c#ifdef W2_FILL_NULL_REGIONS
c#include "W2_EXCH2_PARAMS.h"
c#endif

C     !INPUT/OUTPUT PARAMETERS:
C     === Routine arguments ===
C     phi    :: Array with overlap regions are to be exchanged
C     myNz   :: 3rd dimension of array to exchange
C     myThid :: My thread id.
      INTEGER myNz
      _R8 phi(1-OLx:sNx+OLx,1-OLy:sNy+OLy,myNz,nSx,nSy)
      INTEGER myThid

C     !LOCAL VARIABLES:
C     == Local variables ==
C     OL[wens]       :: Overlap extents in west, east, north, south.
C     exchWidth[XY]  :: Extent of regions that will be exchanged.
      INTEGER OLw, OLe, OLn, OLs, exchWidthX, exchWidthY
#ifdef W2_FILL_NULL_REGIONS
      INTEGER bi, bj, myTile, i, j, k
#endif

CEOP

      OLw        = OLx
      OLe        = OLx
      OLn        = OLy
      OLs        = OLy
      exchWidthX = OLx
      exchWidthY = OLy

      CALL EXCH2_R81_CUBE( phi, .FALSE., 'T ',
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_IGNORE_CORNERS, myThid )

      CALL EXCH2_R81_CUBE( phi, .FALSE., 'T ',
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )

#ifdef W2_FILL_NULL_REGIONS
      IF (useCubedSphereExchange) THEN
       DO bj=myByLo(myThid),myByHi(myThid)
        DO bi=myBxLo(myThid),myBxHi(myThid)
         myTile = W2_myTileList(bi,bj)
C        South-east corner
         IF ( exch2_isEedge(myTile) .EQ. 1 .AND.
     &        exch2_isSedge(myTile) .EQ. 1 ) THEN
          DO j=1-OLy,0
           DO i=sNx+1,sNx+OLx
            DO k=1,myNz
             phi(i,j,k,bi,bj)=e2FillValue_R8
            ENDDO
           ENDDO
          ENDDO
         ENDIF
C        North-east corner
         IF ( exch2_isEedge(myTile) .EQ. 1 .AND.
     &        exch2_isNedge(myTile) .EQ. 1 ) THEN
          DO j=sNy+1,sNy+OLy
           DO i=sNx+1,sNx+OLx
            DO k=1,myNz
             phi(i,j,k,bi,bj)=e2FillValue_R8
            ENDDO
           ENDDO
          ENDDO
         ENDIF
C        South-west corner
         IF ( exch2_isWedge(myTile) .EQ. 1 .AND.
     &        exch2_isSedge(myTile) .EQ. 1 ) THEN
          DO j=1-OLy,0
           DO i=1-OLx,0
            DO k=1,myNz
             phi(i,j,k,bi,bj)=e2FillValue_R8
            ENDDO
           ENDDO
          ENDDO
         ENDIF
C        North-west corner
         IF ( exch2_isWedge(myTile) .EQ. 1 .AND.
     &        exch2_isNedge(myTile) .EQ. 1 ) THEN
          DO j=sNy+1,sNy+OLy
           DO i=1-OLx,0
            DO k=1,myNz
             phi(i,j,k,bi,bj)=e2FillValue_R8
            ENDDO
           ENDDO
          ENDDO
         ENDIF
        ENDDO
       ENDDO
      ENDIF
#endif /* W2_FILL_NULL_REGIONS */

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

CEH3 ;;; Local Variables: ***
CEH3 ;;; mode:fortran ***
CEH3 ;;; End: ***
