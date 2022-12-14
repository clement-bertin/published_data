#include "CPP_EEOPTIONS.h"
#include "W2_OPTIONS.h"

CBOP
C     !ROUTINE: EXCH_Z_3D_R4

C     !INTERFACE:
      SUBROUTINE EXCH2_Z_3D_R4(
     U                       phi,
     I                       myNz, myThid )
      IMPLICIT NONE
C     !DESCRIPTION:
C     *==========================================================*
C     | SUBROUTINE EXCH_Z_3D_R4
C     | o Handle exchanges for _R4 three-dim zeta-point array.
C     *==========================================================*

C     !USES:
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
C     myNz   :: 3rd dimension of input array phi
C     myThid :: My Thread Id. number
      INTEGER myNz
      _R4 phi(1-OLx:sNx+OLx,1-OLy:sNy+OLy,myNz,nSx,nSy)
      INTEGER myThid

C     !LOCAL VARIABLES:
C     == Local variables ==
C     OL[wens]       :: Overlap extents in west, east, north, south.
C     exchWidth[XY]  :: Extent of regions that will be exchanged.
C     mFace          :: face number
C     local_maxDim   :: upper limit of 3rd dimension value
C     phiNW,phiSE    :: temporary array to hold corner value (CS grid)
C     msgBuf         :: Informational/error message buffer
      INTEGER OLw, OLe, OLn, OLs, exchWidthX, exchWidthY
      INTEGER bi, bj, myTile, i, j, k
      INTEGER mFace
      INTEGER local_maxDim
      PARAMETER( local_maxDim = 8*Nr )
      _R4 phiNW(local_maxDim,nSx,nSy)
      _R4 phiSE(local_maxDim,nSx,nSy)
      CHARACTER*(MAX_LEN_MBUF) msgBuf
CEOP


      OLw        = OLx
      OLe        = OLx
      OLn        = OLy
      OLs        = OLy
      exchWidthX = OLx
      exchWidthY = OLy

      IF (useCubedSphereExchange) THEN
       IF ( myNz.GT.local_maxDim ) THEN
         WRITE(msgBuf,'(2A,2(I4,A))') 'EXCH_Z_3D_R4 :',
     &     ' 3rd dimension=', myNz,
     &     ' exceeds local_maxDim (=', local_maxDim, ' )'
         CALL PRINT_ERROR( msgBuf , myThid )
         WRITE(msgBuf,'(2A)') 'EXCH_Z_3D_R4 :',
     &     ' Increase "local_maxDim" and recompile'
         CALL PRINT_ERROR( msgBuf , myThid )
         STOP 'ABNORMAL END: S/R EXCH_Z_3D_R4'
       ENDIF

C-     save 2 corners value (in case we find 1 "missing corner")
       DO bj=myByLo(myThid),myByHi(myThid)
        DO bi=myBxLo(myThid),myBxHi(myThid)
         DO k=1,myNz
          phiNW(k,bi,bj) = phi(1,sNy+1,k,bi,bj)
          phiSE(k,bi,bj) = phi(sNx+1,1,k,bi,bj)
         ENDDO
        ENDDO
       ENDDO
      ENDIF

       CALL EXCH2_R41_CUBE( phi, .FALSE., 'T ',
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_IGNORE_CORNERS, myThid )
       CALL EXCH2_R41_CUBE( phi, .FALSE., 'T ',
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )

      IF (useCubedSphereExchange) THEN

       DO bj=myByLo(myThid),myByHi(myThid)
        DO bi=myBxLo(myThid),myBxHi(myThid)
         myTile = W2_myTileList(bi,bj)
         mFace  = exch2_myFace(myTile)

C---     Face 2,4,6:
         IF ( MOD(mFace,2).EQ.0 ) THEN

C--      East edge : shift j <- j-1
          IF ( exch2_isEedge(myTile) .EQ. 1 ) THEN
           DO k=1,myNz
            DO j=sNy+OLy,2-OLy,-1
             DO i=sNx+1,sNx+OLx
               phi(i,j,k,bi,bj)=phi(i,j-1,k,bi,bj)
             ENDDO
            ENDDO
           ENDDO
C-       North-East corner
           IF ( exch2_isNedge(myTile) .EQ. 1 ) THEN
            DO k=1,myNz
             DO j=sNy+2,sNy+OLy
              i=sNx-sNy+j
               phi(sNx+1,j,k,bi,bj)=phi(i,sNy+1,k,bi,bj)
             ENDDO
#ifdef W2_FILL_NULL_REGIONS
             DO j=sNy+2,sNy+OLy
              DO i=sNx+2,sNx+OLx
               phi(i,j,k,bi,bj)=e2FillValue_R4
              ENDDO
             ENDDO
#endif
            ENDDO
           ENDIF
          ENDIF
C--      South edge : shift i <- i-1
          IF ( exch2_isSedge(myTile) .EQ. 1 ) THEN
           DO k=1,myNz
            DO j=1-OLy,0
             DO i=sNx+OLx,2-OLx,-1
               phi(i,j,k,bi,bj)=phi(i-1,j,k,bi,bj)
             ENDDO
            ENDDO
           ENDDO
C-       South-East corner
           IF ( exch2_isEedge(myTile) .EQ. 1 ) THEN
            DO k=1,myNz
             phi(sNx+1,1,k,bi,bj)=phiSE(k,bi,bj)
             DO i=sNx+2,sNx+OLx
               j=sNx+2-i
               phi(i,1,k,bi,bj)=phi(sNx+1,j,k,bi,bj)
             ENDDO
#ifdef W2_FILL_NULL_REGIONS
             DO j=1-OLy,0
              DO i=sNx+2,sNx+OLx
               phi(i,j,k,bi,bj)=e2FillValue_R4
              ENDDO
             ENDDO
#endif
            ENDDO
           ENDIF
C-       South-West corner
           IF ( exch2_isWedge(myTile) .EQ. 1 ) THEN
            DO k=1,myNz
             DO j=1-OLy,0
               phi(1,j,k,bi,bj)=phi(j,1,k,bi,bj)
#ifdef W2_FILL_NULL_REGIONS
              DO i=1-OLx,0
               phi(i,j,k,bi,bj)=e2FillValue_R4
              ENDDO
#endif
             ENDDO
            ENDDO
           ENDIF
          ENDIF
C--      North-west corner
          IF ( exch2_isWedge(myTile) .EQ. 1 .AND.
     &         exch2_isNedge(myTile) .EQ. 1 ) THEN
           DO k=1,myNz
             DO i=2-OLx,0
               j=sNy+2-i
               phi(i,sNy+1,k,bi,bj)=phi(1,j,k,bi,bj)
             ENDDO
#ifdef W2_FILL_NULL_REGIONS
             DO j=sNy+2,sNy+OLy
              DO i=1-OLx,0
               phi(i,j,k,bi,bj)=e2FillValue_R4
              ENDDO
             ENDDO
             phi(1-OLx,sNy+1,k,bi,bj)=e2FillValue_R4
#endif
           ENDDO
          ENDIF

         ELSE
C---     Face 1,3,5:

C--      North edge : shift i <- i-1
          IF ( exch2_isNedge(myTile) .EQ. 1 ) THEN
           DO k=1,myNz
            DO j=sNy+1,sNy+OLy
             DO i=sNx+OLx,2-OLx,-1
               phi(i,j,k,bi,bj)=phi(i-1,j,k,bi,bj)
             ENDDO
            ENDDO
           ENDDO
C-       North-East corner
           IF ( exch2_isEedge(myTile) .EQ. 1 ) THEN
            DO k=1,myNz
             DO i=sNx+2,sNx+OLx
               j=sNy-sNx+i
               phi(i,sNy+1,k,bi,bj)=phi(sNx+1,j,k,bi,bj)
             ENDDO
#ifdef W2_FILL_NULL_REGIONS
             DO j=sNy+2,sNy+OLy
              DO i=sNx+2,sNx+OLx
               phi(i,j,k,bi,bj)=e2FillValue_R4
              ENDDO
             ENDDO
#endif
            ENDDO
           ENDIF
          ENDIF
C--      West edge : shift j <- j-1
          IF ( exch2_isWedge(myTile) .EQ. 1 ) THEN
           DO k=1,myNz
            DO j=sNy+OLy,2-OLy,-1
             DO i=1-OLx,0
               phi(i,j,k,bi,bj)=phi(i,j-1,k,bi,bj)
             ENDDO
            ENDDO
           ENDDO
C-       North-west corner
           IF ( exch2_isNedge(myTile) .EQ. 1 ) THEN
            DO k=1,myNz
             phi(1,sNy+1,k,bi,bj)=phiNW(k,bi,bj)
             DO j=sNy+2,sNy+OLy
               i=sNy+2-j
               phi(1,j,k,bi,bj)=phi(i,sNy+1,k,bi,bj)
             ENDDO
#ifdef W2_FILL_NULL_REGIONS
             DO j=sNy+2,sNy+OLy
              DO i=1-OLx,0
               phi(i,j,k,bi,bj)=e2FillValue_R4
              ENDDO
             ENDDO
#endif
            ENDDO
           ENDIF
C-       South-West corner
           IF ( exch2_isSedge(myTile) .EQ. 1 ) THEN
            DO k=1,myNz
             DO i=1-OLx,0
               phi(i,1,k,bi,bj)=phi(1,i,k,bi,bj)
             ENDDO
#ifdef W2_FILL_NULL_REGIONS
             DO j=1-OLy,0
              DO i=1-OLx,0
               phi(i,j,k,bi,bj)=e2FillValue_R4
              ENDDO
             ENDDO
#endif
            ENDDO
           ENDIF
          ENDIF
C-       South-East corner
          IF ( exch2_isEedge(myTile) .EQ. 1 .AND.
     &         exch2_isSedge(myTile) .EQ. 1 ) THEN
            DO k=1,myNz
             DO j=2-OLy,0
               i=sNx+2-j
               phi(sNx+1,j,k,bi,bj)=phi(i,1,k,bi,bj)
             ENDDO
#ifdef W2_FILL_NULL_REGIONS
             DO j=1-OLy,0
              DO i=sNx+2,sNx+OLx
               phi(i,j,k,bi,bj)=e2FillValue_R4
              ENDDO
             ENDDO
             phi(sNx+1,1-OLy,k,bi,bj)=e2FillValue_R4
#endif
            ENDDO
          ENDIF

C---     end odd / even face number
         ENDIF

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
