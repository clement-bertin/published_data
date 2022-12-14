#include "CPP_EEOPTIONS.h"
#undef EXCH_USE_SPINNING

CBOP
C     !ROUTINE: EXCH_RL_RECV_GET_X

C     !INTERFACE:
      SUBROUTINE EXCH_RL_RECV_GET_X( array,
     I            myOLw, myOLe, myOLs, myOLn, myNz,
     I            exchWidthX, exchWidthY,
     I            theSimulationMode, theCornerMode, myThid )
      IMPLICIT NONE

C     !DESCRIPTION:
C     *==========================================================*
C     | SUBROUTINE RECV_RL_GET_X
C     | o "Send" or "put" X edges for RL array.
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
C                         support for adjoint integration of code. )
C     theCornerMode     :: Flag indicating whether corner updates are
C                         needed.
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
C     biW, bjW                   :: West tile indices
C     biE, bjE                   :: East tile indices
C     eBl                        :: Current exchange buffer level
C     theProc, theTag, theType,  :: Variables used in message building
C     theSize
C     westCommMode               :: Working variables holding type
C     eastCommMode                  of communication a particular
C                                   tile face uses.
      INTEGER i, j, k, iMin, iMax, iB, iB0
      INTEGER bi, bj, biW, bjW, biE, bjE
      INTEGER eBl
      INTEGER westCommMode
      INTEGER eastCommMode
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
        westCommMode = _tileCommModeW(bi,bj)
        eastCommMode = _tileCommModeE(bi,bj)
        biE = _tileBiE(bi,bj)
        bjE = _tileBjE(bi,bj)
        biW = _tileBiW(bi,bj)
        bjW = _tileBjW(bi,bj)
        theType = _MPI_TYPE_RL
        theSize = sNy*exchWidthX*myNz

        IF ( westCommMode .EQ. COMM_MSG ) THEN
         theProc = tilePidW(bi,bj)
         theTag  = _tileTagRecvW(bi,bj)
# ifndef ALLOW_AUTODIFF_OPENAD_AMPI
         CALL MPI_Recv( westRecvBuf_RL(1,eBl,bi,bj), theSize,
     &                  theType, theProc, theTag, MPI_COMM_MODEL,
     &                  mpiStatus, mpiRc )
# else
         pReqI=exchNReqsX(1,bi,bj)+1
         CALL ampi_recv_RL(
     &        westRecvBuf_RL(1,eBl,bi,bj) ,
     &        theSize ,
     &        theType ,
     &        theProc ,
     &        theTag ,
     &        MPI_COMM_MODEL ,
     &        exchReqIdX(pReqI,1,bi,bj),
     &        exchNReqsX(1,bi,bj),
     &        mpiStatus ,
     &        mpiRc )
# endif /* ALLOW_AUTODIFF_OPENAD_AMPI */
         westRecvAck(eBl,bi,bj) = 1
        ENDIF

        IF ( eastCommMode .EQ. COMM_MSG ) THEN
         theProc = tilePidE(bi,bj)
         theTag  = _tileTagRecvE(bi,bj)
# ifndef ALLOW_AUTODIFF_OPENAD_AMPI
         CALL MPI_Recv( eastRecvBuf_RL(1,eBl,bi,bj), theSize,
     &                  theType, theProc, theTag, MPI_COMM_MODEL,
     &                  mpiStatus, mpiRc )
# else
         pReqI=exchNReqsX(1,bi,bj)+1
         CALL ampi_recv_RL(
     &        eastRecvBuf_RL(1,eBl,bi,bj) ,
     &        theSize ,
     &        theType ,
     &        theProc ,
     &        theTag ,
     &        MPI_COMM_MODEL ,
     &        exchReqIdX(pReqI,1,bi,bj),
     &        exchNReqsX(1,bi,bj),
     &        mpiStatus ,
     &        mpiRc )
# endif /* ALLOW_AUTODIFF_OPENAD_AMPI */
         eastRecvAck(eBl,bi,bj) = 1
        ENDIF
       ENDDO
      ENDDO

C--   Processes wait for buffers I am going to read to be ready.
      IF ( .NOT.exchUsesBarrier  ) THEN
       DO bj=1,nSy
        DO bi=1,nSx
         IF ( exchNReqsX(1,bi,bj) .GT. 0 ) THEN
# ifndef ALLOW_AUTODIFF_OPENAD_AMPI
          CALL MPI_Waitall( exchNReqsX(1,bi,bj), exchReqIdX(1,1,bi,bj),
     &                      mpiStatus, mpiRC )
# else
          CALL ampi_waitall(
     &         exchNReqsX(1,bi,bj),
     &         exchReqIdX(1,1,bi,bj),
     &         mpiStatus,
     &         mpiRC )
# endif /* ALLOW_AUTODIFF_OPENAD_AMPI */
         ENDIF
C        Clear outstanding requests counter
         exchNReqsX(1,bi,bj) = 0
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
         westCommMode = _tileCommModeW(bi,bj)
         eastCommMode = _tileCommModeE(bi,bj)
# ifndef ALLOW_AUTODIFF_OPENAD_AMPI
   10    CONTINUE
          CALL FOOL_THE_COMPILER( spinCount )
          spinCount = spinCount+1
C         IF ( myThid .EQ. 1 .AND. spinCount .GT. _EXCH_SPIN_LIMIT ) THEN
C          WRITE(*,*) ' eBl = ', ebl
C          STOP ' S/R EXCH_RECV_GET_X: spinCount .GT. _EXCH_SPIN_LIMIT'
C         ENDIF
          IF ( westRecvAck(eBl,bi,bj) .EQ. 0 ) GOTO 10
          IF ( eastRecvAck(eBl,bi,bj) .EQ. 0 ) GOTO 10
# else
         DO WHILE ((westRecvAck(eBl,bi,bj) .EQ. 0
     &             .OR.
     &              eastRecvAck(eBl,bi,bj) .EQ. 0 ))
          CALL FOOL_THE_COMPILER( spinCount )
          spinCount = spinCount+1
         ENDDO
# endif /* ALLOW_AUTODIFF_OPENAD_AMPI */
C        Clear outstanding requests
         westRecvAck(eBl,bi,bj) = 0
         eastRecvAck(eBl,bi,bj) = 0
C        Update statistics
         IF ( exchCollectStatistics ) THEN
          exchRecvXExchCount(1,bi,bj) = exchRecvXExchCount(1,bi,bj)+1
          exchRecvXSpinCount(1,bi,bj) =
     &    exchRecvXSpinCount(1,bi,bj)+spinCount
          exchRecvXSpinMax(1,bi,bj) =
     &    MAX(exchRecvXSpinMax(1,bi,bj),spinCount)
          exchRecvXSpinMin(1,bi,bj) =
     &    MIN(exchRecvXSpinMin(1,bi,bj),spinCount)
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
        biE = _tileBiE(bi,bj)
        bjE = _tileBjE(bi,bj)
        biW = _tileBiW(bi,bj)
        bjW = _tileBjW(bi,bj)
        westCommMode = _tileCommModeW(bi,bj)
        eastCommMode = _tileCommModeE(bi,bj)

        IF     ( _theSimulationMode .EQ. FORWARD_SIMULATION ) THEN
         iMin = sNx+1
         iMax = sNx+exchWidthX
         iB0  = 0
         IF (     eastCommMode .EQ. COMM_PUT
     &       .OR. eastCommMode .EQ. COMM_MSG ) THEN
          iB  = 0
          DO k=1,myNz
           DO j=1,sNy
            DO i=iMin,iMax
             iB = iB + 1
             array(i,j,k,bi,bj) = eastRecvBuf_RL(iB,eBl,bi,bj)
            ENDDO
           ENDDO
          ENDDO
         ELSEIF ( eastCommMode .EQ. COMM_GET ) THEN
          DO k=1,myNz
           DO j=1,sNy
            iB = iB0
            DO i=iMin,iMax
             iB = iB+1
             array(i,j,k,bi,bj) = array(iB,j,k,biE,bjE)
            ENDDO
           ENDDO
          ENDDO
         ENDIF
        ELSEIF ( _theSimulationMode .EQ. REVERSE_SIMULATION ) THEN
         iMin = sNx-exchWidthX+1
         iMax = sNx
         iB0  = 1-exchWidthX-1
         IF (     eastCommMode .EQ. COMM_PUT
     &       .OR. eastCommMode .EQ. COMM_MSG ) THEN
          iB  = 0
          DO k=1,myNz
           DO j=1,sNy
            DO i=iMin,iMax
             iB = iB + 1
             array(i,j,k,bi,bj) =
     &       array(i,j,k,bi,bj) + eastRecvBuf_RL(iB,eBl,bi,bj)
            ENDDO
           ENDDO
          ENDDO
         ELSEIF ( eastCommMode .EQ. COMM_GET ) THEN
          DO k=1,myNz
           DO j=1,sNy
            iB = iB0
            DO i=iMin,iMax
             iB = iB+1
             array(i,j,k,bi,bj) =
     &       array(i,j,k,bi,bj) + array(iB,j,k,biE,bjE)
             array(iB,j,k,biE,bjE) = 0.0
            ENDDO
           ENDDO
          ENDDO
         ENDIF
        ENDIF

        IF     ( _theSimulationMode .EQ. FORWARD_SIMULATION ) THEN
         iMin = 1-exchWidthX
         iMax = 0
         iB0  = sNx-exchWidthX
         IF (      westCommMode .EQ. COMM_PUT
     &        .OR. westCommMode .EQ. COMM_MSG ) THEN
          iB  = 0
          DO k=1,myNz
           DO j=1,sNy
            DO i=iMin,iMax
             iB = iB + 1
             array(i,j,k,bi,bj) = westRecvBuf_RL(iB,eBl,bi,bj)
            ENDDO
           ENDDO
          ENDDO
         ELSEIF ( westCommMode .EQ. COMM_GET ) THEN
          DO k=1,myNz
           DO j=1,sNy
            iB = iB0
            DO i=iMin,iMax
             iB = iB+1
             array(i,j,k,bi,bj) = array(iB,j,k,biW,bjW)
            ENDDO
           ENDDO
          ENDDO
         ENDIF
        ELSEIF ( _theSimulationMode .EQ. REVERSE_SIMULATION ) THEN
         iMin = 1
         iMax = 1+exchWidthX-1
         iB0  = sNx
         IF (     westCommMode .EQ. COMM_PUT
     &       .OR. westCommMode .EQ. COMM_MSG ) THEN
          iB  = 0
          DO k=1,myNz
           DO j=1,sNy
            DO i=iMin,iMax
             iB = iB + 1
             array(i,j,k,bi,bj) =
     &       array(i,j,k,bi,bj) + westRecvBuf_RL(iB,eBl,bi,bj)
            ENDDO
           ENDDO
          ENDDO
         ELSEIF ( westCommMode .EQ. COMM_GET ) THEN
          DO k=1,myNz
           DO j=1,sNy
            iB = iB0
            DO i=iMin,iMax
             iB = iB+1
             array(i,j,k,bi,bj) =
     &       array(i,j,k,bi,bj) + array(iB,j,k,biW,bjW)
             array(iB,j,k,biW,bjW) = 0.0
            ENDDO
           ENDDO
          ENDDO
         ENDIF
        ENDIF

       ENDDO
      ENDDO

      RETURN
      END
