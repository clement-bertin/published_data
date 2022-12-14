#include "CPP_EEOPTIONS.h"
#undef EXCH_USE_SPINNING

CBOP
C     !ROUTINE: EXCH_RL_RECV_GET_Y

C     !INTERFACE:
      SUBROUTINE EXCH_RL_RECV_GET_Y( array,
     I            myOLw, myOLe, myOLs, myOLn, myNz,
     I            exchWidthX, exchWidthY,
     I            theSimulationMode, theCornerMode, myThid )
      IMPLICIT NONE

C     !DESCRIPTION:
C     *==========================================================*
C     | SUBROUTINE RECV_GET_Y
C     | o "Send" or "put" Y edges for RL array.
C     *==========================================================*
C     | Routine that invokes actual message passing send or
C     | direct "put" of data to update X faces of an XY[R] array.
C     *==========================================================*

C     !USES:
C     == Global variables ==
#include "SIZE.h"
#include "EEPARAMS.h"
#include "EESUPPORT.h"
#include "EXCH.h"

C     !INPUT/OUTPUT PARAMETERS:
C     == Routine arguments ==
C     array :: Array with edges to exchange.
C     myOLw :: West, East, North and South overlap region sizes.
C     myOLe
C     myOLn
C     myOLs
C     exchWidthX :: Width of data region exchanged.
C     exchWidthY
C     theSimulationMode :: Forward or reverse mode exchange ( provides
C                          support for adjoint integration of code. )
C     theCornerMode     :: Flag indicating whether corner updates are
C                          needed.
C     myThid            :: Thread number of this instance of S/R EXCH...
C     eBl               :: Edge buffer level
      INTEGER myOLw
      INTEGER myOLe
      INTEGER myOLs
      INTEGER myOLn
      INTEGER myNz
      _RL array(1-myOLw:sNx+myOLe,
     &          1-myOLs:sNy+myOLn,
     &          myNZ, nSx, nSy)
      INTEGER exchWidthX
      INTEGER exchWidthY
      INTEGER theSimulationMode
      INTEGER theCornerMode
      INTEGER myThid

C     !LOCAL VARIABLES:
C     == Local variables ==
C     i, j, k, iMin, iMax, iB    :: Loop counters and extents
C     bi, bj
C     biS, bjS                   :: South tile indices
C     biN, bjN                   :: North tile indices
C     eBl                        :: Current exchange buffer level
C     theProc, theTag, theType,  :: Variables used in message building
C     theSize
C     southCommMode              :: Working variables holding type
C     northCommMode                 of communication a particular
C                                   tile face uses.
C     spinCount                  :: Exchange statistics counter
C     mpiStatus                  :: MPI error code
      INTEGER i, j, k, iMin, iMax, jMin, jMax, iB, iB0
      INTEGER bi, bj, biS, bjS, biN, bjN
      INTEGER eBl
      INTEGER southCommMode
      INTEGER northCommMode
#ifdef EXCH_USE_SPINNING
      INTEGER spinCount
#endif
#ifdef ALLOW_USE_MPI
      INTEGER theProc, theTag, theType, theSize
      INTEGER mpiStatus(MPI_STATUS_SIZE,4), mpiRc
# ifdef ALLOW_AUTODIFF_OPENAD_AMPI
      INTEGER pReqI
# endif
#endif /* ALLOW_USE_MPI */
CEOP

C--   Under a "put" scenario we
C--     i. set completetion signal for buffer we put into.
C--    ii. wait for completetion signal indicating data has been put in
C--        our buffer.
C--   Under a messaging mode we "receive" the message.
C--   Under a "get" scenario we
C--     i. Check that the data is ready.
C--    ii. Read the data.
C--   iii. Set data read flag + memory sync.

#ifdef ALLOW_USE_MPI
      IF ( usingMPI ) THEN

C--   Receive buffer data: Only Master Thread do proc communication
      _BEGIN_MASTER(myThid)

      DO bj=1,nSy
       DO bi=1,nSx
        eBl = exchangeBufLevel(1,bi,bj)
        southCommMode = _tileCommModeS(bi,bj)
        northCommMode = _tileCommModeN(bi,bj)
        biN = _tileBiN(bi,bj)
        bjN = _tileBjN(bi,bj)
        biS = _tileBiS(bi,bj)
        bjS = _tileBjS(bi,bj)
        theType = _MPI_TYPE_RL
        theSize = sNx*exchWidthY*myNz
        IF ( theCornerMode .EQ. EXCH_UPDATE_CORNERS ) THEN
          theSize = (sNx+2*exchWidthX)*exchWidthY*myNz
        ENDIF

        IF ( southCommMode .EQ. COMM_MSG ) THEN
         theProc = tilePidS(bi,bj)
         theTag  = _tileTagRecvS(bi,bj)
# ifndef ALLOW_AUTODIFF_OPENAD_AMPI
         CALL MPI_Recv( southRecvBuf_RL(1,eBl,bi,bj), theSize,
     &                  theType, theProc, theTag, MPI_COMM_MODEL,
     &                  mpiStatus, mpiRc )
# else
         pReqI=exchNReqsY(1,bi,bj)+1
         CALL ampi_recv_RL(
     &        southRecvBuf_RL(1,eBl,bi,bj) ,
     &        theSize ,
     &        theType ,
     &        theProc ,
     &        theTag ,
     &        MPI_COMM_MODEL ,
     &        exchReqIdY(pReqI,1,bi,bj),
     &        exchNReqsY(1,bi,bj),
     &        mpiStatus ,
     &        mpiRc )
# endif /* ALLOW_AUTODIFF_OPENAD_AMPI */
         southRecvAck(eBl,bi,bj) = 1
        ENDIF

        IF ( northCommMode .EQ. COMM_MSG ) THEN
         theProc = tilePidN(bi,bj)
         theTag  = _tileTagRecvN(bi,bj)
# ifndef ALLOW_AUTODIFF_OPENAD_AMPI
         CALL MPI_Recv( northRecvBuf_RL(1,eBl,bi,bj), theSize,
     &                  theType, theProc, theTag, MPI_COMM_MODEL,
     &                  mpiStatus, mpiRc )
# else
         pReqI=exchNReqsY(1,bi,bj)+1
         CALL ampi_recv_RL(
     &        northRecvBuf_RL(1,eBl,bi,bj) ,
     &        theSize ,
     &        theType ,
     &        theProc ,
     &        theTag ,
     &        MPI_COMM_MODEL ,
     &        exchReqIdY(pReqI,1,bi,bj),
     &        exchNReqsY(1,bi,bj),
     &        mpiStatus ,
     &        mpiRc )
# endif /* ALLOW_AUTODIFF_OPENAD_AMPI */
         northRecvAck(eBl,bi,bj) = 1
        ENDIF
       ENDDO
      ENDDO

C--   Processes wait for buffers I am going to read to be ready.
      IF ( .NOT.exchUsesBarrier  ) THEN
       DO bj=1,nSy
        DO bi=1,nSx
         IF ( exchNReqsY(1,bi,bj) .GT. 0 ) THEN
# ifndef ALLOW_AUTODIFF_OPENAD_AMPI
          CALL MPI_Waitall( exchNReqsY(1,bi,bj), exchReqIdY(1,1,bi,bj),
     &                      mpiStatus, mpiRC )
# else
          CALL ampi_waitall(
     &         exchNReqsY(1,bi,bj),
     &         exchReqIdY(1,1,bi,bj),
     &         mpiStatus,
     &         mpiRC )
# endif /* ALLOW_AUTODIFF_OPENAD_AMPI */
         ENDIF
C        Clear outstanding requests counter
         exchNReqsY(1,bi,bj) = 0
        ENDDO
       ENDDO
      ENDIF

      _END_MASTER(myThid)
C--   need to sync threads after master has received data ;
C     (done after mpi waitall in case waitall is really needed)
      _BARRIER

      ENDIF
#endif /* ALLOW_USE_MPI */

C--   Threads wait for buffers I am going to read to be ready.
C     note: added BARRIER in exch_send_put S/R and here above (message mode)
C           so that we no longer needs this (undef EXCH_USE_SPINNING)
#ifdef EXCH_USE_SPINNING
      IF ( exchUsesBarrier  ) THEN
C      o On some machines ( T90 ) use system barrier rather than spinning.
       CALL BARRIER( myThid )
      ELSE
C      o Spin waiting for completetion flag. This avoids a global-lock
C        i.e. we only lock waiting for data that we need.
       DO bj=myByLo(myThid),myByHi(myThid)
        DO bi=myBxLo(myThid),myBxHi(myThid)

         spinCount = 0
         eBl = exchangeBufLevel(1,bi,bj)
         southCommMode = _tileCommModeS(bi,bj)
         northCommMode = _tileCommModeN(bi,bj)
# ifndef ALLOW_AUTODIFF_OPENAD_AMPI
   10    CONTINUE
          CALL FOOL_THE_COMPILER( spinCount )
          spinCount = spinCount+1
C         IF ( myThid .EQ. 1 .AND. spinCount .GT. _EXCH_SPIN_LIMIT ) THEN
C          STOP ' S/R EXCH_RECV_GET_Y: spinCount .GT. _EXCH_SPIN_LIMIT'
C         ENDIF
          IF ( southRecvAck(eBl,bi,bj) .EQ. 0 ) GOTO 10
          IF ( northRecvAck(eBl,bi,bj) .EQ. 0 ) GOTO 10
# else
         DO WHILE ((southRecvAck(eBl,bi,bj) .EQ. 0
     &             .OR.
     &              northRecvAck(eBl,bi,bj) .EQ. 0 ))
          CALL FOOL_THE_COMPILER( spinCount )
          spinCount = spinCount+1
         ENDDO
# endif /* ALLOW_AUTODIFF_OPENAD_AMPI */
C        Clear requests
         southRecvAck(eBl,bi,bj) = 0
         northRecvAck(eBl,bi,bj) = 0
C        Update statistics
         IF ( exchCollectStatistics ) THEN
          exchRecvYExchCount(1,bi,bj) = exchRecvYExchCount(1,bi,bj)+1
          exchRecvYSpinCount(1,bi,bj) =
     &    exchRecvYSpinCount(1,bi,bj)+spinCount
          exchRecvYSpinMax(1,bi,bj) =
     &    MAX(exchRecvYSpinMax(1,bi,bj),spinCount)
          exchRecvYSpinMin(1,bi,bj) =
     &    MIN(exchRecvYSpinMin(1,bi,bj),spinCount)
         ENDIF

        ENDDO
       ENDDO
      ENDIF
#endif /* EXCH_USE_SPINNING */

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

C--   Read from the buffers
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)

        eBl = exchangeBufLevel(1,bi,bj)
        biN = _tileBiN(bi,bj)
        bjN = _tileBjN(bi,bj)
        biS = _tileBiS(bi,bj)
        bjS = _tileBjS(bi,bj)
        southCommMode = _tileCommModeS(bi,bj)
        northCommMode = _tileCommModeN(bi,bj)
        IF ( theCornerMode .EQ. EXCH_UPDATE_CORNERS ) THEN
         iMin =   1-exchWidthX
         iMax = sNx+exchWidthX
        ELSE
         iMin = 1
         iMax = sNx
        ENDIF
        IF     ( _theSimulationMode .EQ. FORWARD_SIMULATION ) THEN
         jMin = sNy+1
         jMax = sNy+exchWidthY
         iB0  = 0
         IF (     northCommMode .EQ. COMM_PUT
     &       .OR. northCommMode .EQ. COMM_MSG  ) THEN
          iB  = 0
          DO k=1,myNz
           DO j=jMin,jMax
            DO i=iMin,iMax
             iB = iB + 1
             array(i,j,k,bi,bj) = northRecvBuf_RL(iB,eBl,bi,bj)
            ENDDO
           ENDDO
          ENDDO
         ELSEIF ( northCommMode .EQ. COMM_GET ) THEN
          DO k=1,myNz
           iB = iB0
           DO j=jMin,jMax
            iB = iB+1
            DO i=iMin,iMax
             array(i,j,k,bi,bj) = array(i,iB,k,biN,bjN)
            ENDDO
           ENDDO
          ENDDO
         ENDIF
        ELSEIF ( _theSimulationMode .EQ. REVERSE_SIMULATION ) THEN
         jMin = sNy-exchWidthY+1
         jMax = sNy
         iB0  = 1-exchWidthY-1
         IF (     northCommMode .EQ. COMM_PUT
     &       .OR. northCommMode .EQ. COMM_MSG  ) THEN
          iB  = 0
          DO k=1,myNz
           DO j=jMin,jMax
            DO i=iMin,iMax
             iB = iB + 1
             array(i,j,k,bi,bj) =
     &       array(i,j,k,bi,bj) + northRecvBuf_RL(iB,eBl,bi,bj)
            ENDDO
           ENDDO
          ENDDO
         ELSEIF ( northCommMode .EQ. COMM_GET ) THEN
          DO k=1,myNz
           iB = iB0
           DO j=jMin,jMax
            iB = iB+1
            DO i=iMin,iMax
             array(i,j,k,bi,bj) =
     &       array(i,j,k,bi,bj) + array(i,iB,k,biN,bjN)
             array(i,iB,k,biN,bjN) = 0.0
            ENDDO
           ENDDO
          ENDDO
         ENDIF
        ENDIF

        IF     ( _theSimulationMode .EQ. FORWARD_SIMULATION ) THEN
         jMin = 1-exchWidthY
         jMax = 0
         iB0  = sNy-exchWidthY
         IF (     southCommMode .EQ. COMM_PUT
     &       .OR. southCommMode .EQ. COMM_MSG ) THEN
          iB  = 0
          DO k=1,myNz
           DO j=jMin,jMax
            DO i=iMin,iMax
             iB = iB + 1
             array(i,j,k,bi,bj) = southRecvBuf_RL(iB,eBl,bi,bj)
            ENDDO
           ENDDO
          ENDDO
         ELSEIF ( southCommMode .EQ. COMM_GET ) THEN
          DO k=1,myNz
           iB = iB0
           DO j=jMin,jMax
            iB = iB+1
            DO i=iMin,iMax
             array(i,j,k,bi,bj) = array(i,iB,k,biS,bjS)
            ENDDO
           ENDDO
          ENDDO
         ENDIF
        ELSEIF ( _theSimulationMode .EQ. REVERSE_SIMULATION ) THEN
         jMin = 1
         jMax = 1+exchWidthY-1
         iB0  = sNy
         IF (     southCommMode .EQ. COMM_PUT
     &       .OR. southCommMode .EQ. COMM_MSG ) THEN
          iB  = 0
          DO k=1,myNz
           DO j=jMin,jMax
            DO i=iMin,iMax
             iB = iB + 1
             array(i,j,k,bi,bj) =
     &       array(i,j,k,bi,bj) + southRecvBuf_RL(iB,eBl,bi,bj)
            ENDDO
           ENDDO
          ENDDO
         ELSEIF ( southCommMode .EQ. COMM_GET ) THEN
          DO k=1,myNz
           iB = iB0
           DO j=jMin,jMax
            iB = iB+1
            DO i=iMin,iMax
             array(i,j,k,bi,bj) =
     &       array(i,j,k,bi,bj) + array(i,iB,k,biS,bjS)
             array(i,iB,k,biS,bjS) = 0.0
            ENDDO
           ENDDO
          ENDDO
         ENDIF
        ENDIF

       ENDDO
      ENDDO

      RETURN
      END
