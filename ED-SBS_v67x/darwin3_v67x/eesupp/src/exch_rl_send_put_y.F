#include "CPP_EEOPTIONS.h"

CBOP
C     !ROUTINE: EXCH_RL_SEND_PUT_Y

C     !INTERFACE:
      SUBROUTINE EXCH_RL_SEND_PUT_Y( array,
     I             myOLw, myOLe, myOLs, myOLn, myNz,
     I             exchWidthX, exchWidthY,
     I             thesimulationMode, thecornerMode, myThid )
      IMPLICIT NONE
C     !DESCRIPTION:
C     *==========================================================*
C     | SUBROUTINE SEND_PUT_Y
C     | o "Send" or "put" Y edges for RL array.
C     *==========================================================*
C     | Routine that invokes actual message passing send or
C     | direct "put" of data to update Y faces of an XY[R] array.
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
C                          Note - the reverse mode for an assignment
C                                 is an accumulation. This means that
C                                 put implementations that do leary things
C                                 like writing to overlap regions in a
C                                 remote process need to be even more
C                                 careful. You need to be pretty careful
C                                 in forward mode too!
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
C     i, j, k, jMin, jMax, iB    - Loop counters and extents
C     bi, bj
C     biS, bjS                   - South tile indices
C     biN, bjN                   - North tile indices
C     eBl                        - Current exchange buffer level
C     theProc, theTag, theType,  - Variables used in message building
C     theSize
C     southCommMode              - Working variables holding type
C     northCommMode                of communication a particular
C                                  tile face uses.
      INTEGER i, j, k, jMin, jMax, iMin, iMax, iB
      INTEGER bi, bj, biS, bjS, biN, bjN
      INTEGER eBl
      INTEGER northCommMode
      INTEGER southCommMode
#ifdef ALLOW_USE_MPI
      INTEGER theProc, theTag, theType, theSize, mpiRc
# ifdef ALLOW_AUTODIFF_OPENAD_AMPI
      INTEGER mpiStatus(MPI_STATUS_SIZE)
      INTEGER pReqI
# endif
#endif

C--   Write data to exchange buffer
C     Various actions are possible depending on the communication mode
C     as follows:
C       Mode      Action
C     --------   ---------------------------
C     COMM_NONE  Do nothing
C
C     COMM_MSG   Message passing communication ( e.g. MPI )
C                Fill south send buffer from this tile.
C                Send data with tag identifying tile and direction.
C                Fill north send buffer from this tile.
C                Send data with tag identifying tile and direction.
C
C     COMM_PUT   "Put" communication ( UMP_, shmemput, etc... )
C                Fill south receive buffer of south-neighbor tile
C                Fill north receive buffer of north-neighbor tile
C                Sync. memory
C                Write data-ready Ack for north edge of south-neighbor
C                tile
C                Write data-ready Ack for south edge of north-neighbor
C                tile
C                Sync. memory
CEOP

#ifdef ALLOW_AUTODIFF_OPENAD_AMPI
# ifdef ALLOW_USE_MPI
      IF ( usingMPI ) THEN
      _BEGIN_MASTER(myThid)
       DO bj=1,nSy
        DO bi=1,nSx
          CALL ampi_awaitall (
     &         exchNReqsY(1,bi,bj) ,
     &         exchReqIdY(1,1,bi,bj) ,
     &         mpiStatus ,
     &         mpiRC )
        ENDDO
       ENDDO
      _END_MASTER(myThid)
      ENDIF
# endif
#endif

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

C     Prevent anyone to access shared buffer while an other thread modifies it
      _BARRIER

C     Fill shared buffers from array values
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)

        eBl = exchangeBufLevel(1,bi,bj)
        southCommMode = _tileCommModeS(bi,bj)
        northCommMode = _tileCommModeN(bi,bj)
        biS = _tileBiS(bi,bj)
        bjS = _tileBjS(bi,bj)
        biN = _tileBiN(bi,bj)
        bjN = _tileBjN(bi,bj)
        iMin = 1
        iMax = sNx
        IF ( theCornerMode .EQ. EXCH_UPDATE_CORNERS ) THEN
         iMin =   1-exchWidthX
         iMax = sNx+exchWidthX
        ENDIF

C     >>>>>>>>>>>>>>>>>>> FORWARD RUN <<<<<<<<<<<<<<<<<<<

        IF ( _theSimulationMode .EQ. FORWARD_SIMULATION ) THEN

C       o Send or Put south edge
         jMin = 1
         jMax = 1+exchWidthY-1
         IF ( southCommMode .EQ. COMM_MSG  ) THEN
          iB = 0
          DO k=1,myNz
           DO j=jMin,jMax
            DO i=iMin,iMax
             iB = iB + 1
             southSendBuf_RL(iB,eBl,bi,bj) = array(i,j,k,bi,bj)
            ENDDO
           ENDDO
          ENDDO
         ELSEIF ( southCommMode .EQ. COMM_PUT  ) THEN
          iB  = 0
          DO k=1,myNz
           DO j=jMin,jMax
            DO i=iMin,iMax
             iB = iB + 1
             northRecvBuf_RL(iB,eBl,biS,bjS) = array(i,j,k,bi,bj)
            ENDDO
           ENDDO
          ENDDO
         ELSEIF ( southCommMode .NE. COMM_NONE
     &    .AND.   southCommMode .NE. COMM_GET ) THEN
          STOP ' S/R EXCH: Invalid commS mode.'
         ENDIF

C       o Send or Put north edge
         jMin = sNy-exchWidthY+1
         jMax = sNy
         IF ( northCommMode .EQ. COMM_MSG  ) THEN
          iB = 0
          DO k=1,myNz
           DO j=jMin,jMax
            DO i=iMin,iMax
             iB = iB + 1
             northSendBuf_RL(iB,eBl,bi,bj) = array(i,j,k,bi,bj)
            ENDDO
           ENDDO
          ENDDO
        ELSEIF ( northCommMode .EQ. COMM_PUT  ) THEN
         iB  = 0
         DO k=1,myNz
          DO j=jMin,jMax
           DO i=iMin,iMax
            iB = iB + 1
            southRecvBuf_RL(iB,eBl,biN,bjN) = array(i,j,k,bi,bj)
           ENDDO
          ENDDO
         ENDDO
        ELSEIF ( northCommMode .NE. COMM_NONE
     &   .AND.   northCommMode .NE. COMM_GET  ) THEN
         STOP ' S/R EXCH: Invalid commN mode.'
        ENDIF

C     >>>>>>>>>>>>>>>>>>> ADJOINT RUN <<<<<<<<<<<<<<<<<<<

        ELSEIF ( _theSimulationMode .EQ. REVERSE_SIMULATION ) THEN

C       o Send or Put south edge
         jMin = 1-exchWidthY
         jMax = 0
         IF ( southCommMode .EQ. COMM_MSG  ) THEN
          iB = 0
          DO k=1,myNz
           DO j=jMin,jMax
            DO i=iMin,iMax
             iB = iB + 1
             southSendBuf_RL(iB,eBl,bi,bj) = array(i,j,k,bi,bj)
              array(i,j,k,bi,bj) = 0.0
           ENDDO
           ENDDO
          ENDDO
         ELSEIF ( southCommMode .EQ. COMM_PUT  ) THEN
          iB  = 0
          DO k=1,myNz
           DO j=jMin,jMax
            DO i=iMin,iMax
             iB = iB + 1
             northRecvBuf_RL(iB,eBl,biS,bjS) = array(i,j,k,bi,bj)
             array(i,j,k,bi,bj) = 0.0
            ENDDO
           ENDDO
          ENDDO
         ELSEIF ( southCommMode .NE. COMM_NONE
     &    .AND.   southCommMode .NE. COMM_GET ) THEN
          STOP ' S/R EXCH: Invalid commS mode.'
         ENDIF

C       o Send or Put north edge
         jMin = sNy+1
         jMax = sNy+exchWidthY
         IF ( northCommMode .EQ. COMM_MSG  ) THEN
          iB = 0
          DO k=1,myNz
           DO j=jMin,jMax
            DO i=iMin,iMax
             iB = iB + 1
             northSendBuf_RL(iB,eBl,bi,bj) = array(i,j,k,bi,bj)
             array(i,j,k,bi,bj) = 0.0
            ENDDO
           ENDDO
          ENDDO
         ELSEIF ( northCommMode .EQ. COMM_PUT  ) THEN
          iB  = 0
          DO k=1,myNz
           DO j=jMin,jMax
            DO i=iMin,iMax
             iB = iB + 1
             southRecvBuf_RL(iB,eBl,biN,bjN) = array(i,j,k,bi,bj)
             array(i,j,k,bi,bj) = 0.0
            ENDDO
           ENDDO
          ENDDO
         ELSEIF ( northCommMode .NE. COMM_NONE
     &    .AND.   northCommMode .NE. COMM_GET  ) THEN
          STOP ' S/R EXCH: Invalid commN mode.'
         ENDIF

        ENDIF

       ENDDO
      ENDDO

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
C--   Signal completetion ( making sure system-wide memory state is
C--                         consistent ).

C     ** NOTE ** We are relying on being able to produce strong-ordered
C     memory semantics here. In other words we assume that there is a
C     mechanism which can ensure that by the time the Ack is seen the
C     overlap region data that will be exchanged is up to date.
      IF ( exchNeedsMemSync  ) CALL MEMSYNC

      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        eBl = exchangeBufLevel(1,bi,bj)
        biS = _tileBiS(bi,bj)
        bjS = _tileBjS(bi,bj)
        biN = _tileBiN(bi,bj)
        bjN = _tileBjN(bi,bj)
        southCommMode = _tileCommModeS(bi,bj)
        northCommMode = _tileCommModeN(bi,bj)
        IF ( southCommMode.EQ.COMM_PUT ) northRecvAck(eBl,biS,bjS) = 1
        IF ( northCommMode.EQ.COMM_PUT ) southRecvAck(eBl,biN,bjN) = 1
        IF ( southCommMode.EQ.COMM_GET ) northRecvAck(eBl,biS,bjS) = 1
        IF ( northCommMode.EQ.COMM_GET ) southRecvAck(eBl,biN,bjN) = 1
       ENDDO
      ENDDO

C--   Make sure "ack" setting is seen system-wide.
C     Here strong-ordering is not an issue but we want to make
C     sure that processes that might spin on the above Ack settings
C     will see the setting.
C     ** NOTE ** On some machines we wont spin on the Ack setting
C     ( particularly the T90 ), instead we will use s system barrier.
C     On the T90 the system barrier is very fast and switches out the
C     thread while it waits. On most machines the system barrier
C     is much too slow and if we own the machine and have one thread
C     per process preemption is not a problem.
      IF ( exchNeedsMemSync  ) CALL MEMSYNC

C     Wait until all threads finish filling buffer
      _BARRIER

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

#ifdef ALLOW_USE_MPI
      IF ( usingMPI ) THEN
C--   Send buffer data: Only Master Thread do proc communication
      _BEGIN_MASTER(myThid)

      DO bj=1,nSy
       DO bi=1,nSx

        eBl = exchangeBufLevel(1,bi,bj)
        southCommMode = _tileCommModeS(bi,bj)
        northCommMode = _tileCommModeN(bi,bj)
        biS = _tileBiS(bi,bj)
        bjS = _tileBjS(bi,bj)
        biN = _tileBiN(bi,bj)
        bjN = _tileBjN(bi,bj)
        theType = _MPI_TYPE_RL
        theSize = sNx*exchWidthY*myNz
        IF ( theCornerMode .EQ. EXCH_UPDATE_CORNERS ) THEN
         theSize = (sNx+2*exchWidthX)*exchWidthY*myNz
        ENDIF

        IF ( southCommMode .EQ. COMM_MSG  ) THEN
C       Send buffer data (copied from south edge)
          theProc = tilePidS(bi,bj)
          theTag  = _tileTagSendS(bi,bj)
# ifndef ALLOW_AUTODIFF_OPENAD_AMPI
          exchNreqsY(1,bi,bj) = exchNreqsY(1,bi,bj)+1
          CALL MPI_Isend( southSendBuf_RL(1,eBl,bi,bj), theSize,
     &                    theType, theProc, theTag, MPI_COMM_MODEL,
     &                    exchReqIdY(exchNreqsY(1,bi,bj),1,bi,bj),
     &                    mpiRc )
# else
          pReqI=exchNReqsY(1,bi,bj)+1
          CALL ampi_isend_RL(
     &         southSendBuf_RL(1,eBl,bi,bj),
     &         theSize,
     &         theType,
     &         theProc,
     &         theTag,
     &         MPI_COMM_MODEL,
     &         exchReqIdY(pReqI,1,bi,bj),
     &         exchNReqsY(1,bi,bj),
     &         mpiStatus,
     &         mpiRc )
# endif /* ALLOW_AUTODIFF_OPENAD_AMPI */
c        northRecvAck(eBl,biS,bjS) = 1
        ENDIF

        IF ( northCommMode .EQ. COMM_MSG  ) THEN
C       Send buffer data (copied from north edge)
          theProc = tilePidN(bi,bj)
          theTag  = _tileTagSendN(bi,bj)
#ifndef ALLOW_AUTODIFF_OPENAD_AMPI
          exchNreqsY(1,bi,bj) = exchNreqsY(1,bi,bj)+1
          CALL MPI_Isend( northSendBuf_RL(1,eBl,bi,bj), theSize,
     &                    theType, theProc, theTag, MPI_COMM_MODEL,
     &                    exchReqIdY(exchNreqsY(1,bi,bj),1,bi,bj),
     &                    mpiRc )
# else
          pReqI=exchNReqsY(1,bi,bj)+1
          CALL ampi_isend_RL(
     &         northSendBuf_RL(1,eBl,bi,bj) ,
     &         theSize ,
     &         theType ,
     &         theProc ,
     &         theTag ,
     &         MPI_COMM_MODEL ,
     &         exchReqIdY(pReqI,1,bi,bj) ,
     &         exchNReqsY(1,bi,bj) ,
     &         mpiStatus ,
     &         mpiRc )
# endif /* ALLOW_AUTODIFF_OPENAD_AMPI */
c         southRecvAck(eBl,biN,bjN) = 1
        ENDIF

       ENDDO
      ENDDO

      _END_MASTER(myThid)

      ENDIF
#endif /* ALLOW_USE_MPI */

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

      RETURN
      END
