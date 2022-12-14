#include "CPP_EEOPTIONS.h"
#undef LOCAL_DBUG

CBOP
C     !ROUTINE: EXCH_RS2_CUBE

C     !INTERFACE:
      SUBROUTINE EXCH2_RS2_CUBE(
     U            array1, array2,
     I            signOption, fieldCode,
     I            myOLw, myOLe, myOLs, myOLn, myNz,
     I            exchWidthX, exchWidthY,
     I            cornerMode, myThid )

C     !DESCRIPTION:
C     Two components vector field Exchange:
C     Fill-in tile-edge overlap-region of a 2 component vector field
C     with corresponding near-edge interior data point

C     !USES:
      IMPLICIT NONE

C     == Global data ==
#include "SIZE.h"
#include "EEPARAMS.h"
#include "EESUPPORT.h"
#include "W2_EXCH2_SIZE.h"
#include "W2_EXCH2_TOPOLOGY.h"
#include "W2_EXCH2_BUFFER.h"

C     !INPUT/OUTPUT PARAMETERS:
C     array1      :: 1rst component array with edges to exchange.
C     array2      :: 2nd  component array with edges to exchange.
C     signOption  :: Flag controlling whether vector is signed.
C     fieldCode   :: field code (position on staggered grid)
C     myOLw,myOLe :: West and East overlap region sizes.
C     myOLs,myOLn :: South and North overlap region sizes.
C     exchWidthX  :: Width of data region exchanged in X.
C     exchWidthY  :: Width of data region exchanged in Y.
C     cornerMode  :: halo-corner-region treatment: update/ignore corner region
C     myThid      :: Thread number of this instance of S/R EXCH...

      INTEGER myOLw, myOLe, myOLs, myOLn, myNz
      _RS array1(1-myOLw:sNx+myOLe,
     &           1-myOLs:sNy+myOLn,
     &           myNz, nSx, nSy)
      _RS array2(1-myOLw:sNx+myOLe,
     &           1-myOLs:sNy+myOLn,
     &           myNz, nSx, nSy)
      LOGICAL signOption
      CHARACTER*2 fieldCode
      INTEGER exchWidthX
      INTEGER exchWidthY
      INTEGER cornerMode
      INTEGER myThid

C     !LOCAL VARIABLES:
C     e2_msgHandles :: Synchronization and coordination data structure used to
C                   :: coordinate access to e2Bufr1_RS or to regulate message
C                   :: buffering. In PUT communication sender will increment
C                   :: handle entry once data is ready in buffer. Receiver will
C                   :: decrement handle once data is consumed from buffer.
C                   :: For MPI MSG communication MPI_Wait uses handle to check
C                   :: Isend has cleared. This is done in routine after receives.
C     note: a) current implementation does not use e2_msgHandles for communication
C              between threads: all-threads barriers are used (see CNH note below).
C              For a 2-threads synchro communication (future version),
C              e2_msgHandles should be shared (in common block, moved to BUFFER.h)
      INTEGER bi, bj
C     Variables for working through W2 topology
      INTEGER e2_msgHandles( 2, W2_maxNeighbours, nSx, nSy )
      INTEGER thisTile, farTile, N, nN, oN
      INTEGER tIlo1, tIhi1, tJlo1, tJhi1, oIs1, oJs1
      INTEGER tIlo2, tIhi2, tJlo2, tJhi2, oIs2, oJs2
      INTEGER tIStride, tJStride
      INTEGER tKlo, tKhi, tKStride
      INTEGER i1Lo, i1Hi, j1Lo, j1Hi, k1Lo, k1Hi
      INTEGER i2Lo, i2Hi, j2Lo, j2Hi, k2Lo, k2Hi
      LOGICAL updateCorners

#ifdef ALLOW_USE_MPI
      INTEGER iBufr1, iBufr2, nri, nrj
C     MPI stuff (should be in a routine call)
      INTEGER mpiStatus(MPI_STATUS_SIZE)
      INTEGER mpiRc
      INTEGER wHandle
#endif
CEOP

      updateCorners = cornerMode .EQ. EXCH_UPDATE_CORNERS
C-    Tile size of arrays to exchange:
      i1Lo  = 1-myOLw
      i1Hi  = sNx+myOLe
      j1Lo  = 1-myOLs
      j1Hi  = sNy+myOLn
      k1Lo  = 1
      k1Hi  = myNz
      i2Lo  = 1-myOLw
      i2Hi  = sNx+myOLe
      j2Lo  = 1-myOLs
      j2Hi  = sNy+myOLn
      k2Lo  = 1
      k2Hi  = myNz

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

C     Prevent anyone to access shared buffer while an other thread modifies it
      CALL BAR2( myThid )

C--   Post sends into buffer (buffer level 1):
      DO bj=myByLo(myThid), myByHi(myThid)
       DO bi=myBxLo(myThid), myBxHi(myThid)
        thisTile=W2_myTileList(bi,bj)
        nN=exch2_nNeighbours(thisTile)
        DO N=1,nN
          farTile=exch2_neighbourId(N,thisTile)
          oN = exch2_opposingSend(N,thisTile)
#ifdef LOCAL_DBUG
          WRITE(errorMessageUnit,'(A,3I3,A,4I4,A,2I5)')
     &      'send_0 bi,N=', bi,bj, N, ' , tI,J_lo,hi=',
     &                  exch2_iLo(oN,farTile), exch2_iHi(oN,farTile),
     &                  exch2_jLo(oN,farTile), exch2_jHi(oN,farTile),
     &      ' , oIs,oJs=', exch2_oi(N,thisTile), exch2_oj(N,thisTile)
#endif
          CALL EXCH2_GET_UV_BOUNDS(
     I               fieldCode, exchWidthX, updateCorners,
     I               farTile, oN,
     O               tIlo1, tIhi1, tJlo1, tJhi1,
     O               tIlo2, tIhi2, tJlo2, tJhi2,
     O               tiStride, tjStride,
     O               oIs1, oJs1, oIs2, oJs2,
     I               myThid )
#ifdef LOCAL_DBUG
          WRITE(errorMessageUnit,'(A,3I3,A,4I4,A,2I5)')
     &      'send_1 bi,N=', bi,bj, N, ' , tI,J_lo,hi=',
     &      tIlo1, tIhi1, tJlo1, tJhi1, ' , oIs,oJs=', oIs1, oJs1
          WRITE(errorMessageUnit,'(A,3I3,A,4I4,A,2I5)')
     &      'send_2 bi,N=', bi,bj, N, ' , tI,J_lo,hi=',
     &      tIlo2, tIhi2, tJlo2, tJhi2, ' , oIs,oJs=', oIs2, oJs2
#endif
          tKLo=1
          tKHi=myNz
          tKStride=1
C-    Put my points in buffer for neighbour N to fill points
C     (tIlo:tIhi:tiStride,tJlo:tJhi,tJStride,tKlo:tKhi,tKStride)
C     in its copy of "array1" & "array2".
          CALL EXCH2_PUT_RS2(
     I               tIlo1, tIhi1, tIlo2, tIhi2, tiStride,
     I               tJlo1, tJhi1, tJlo2, tJhi2, tjStride,
     I               tKlo, tKhi, tkStride,
     I               oIs1, oJs1, oIs2, oJs2,
     I               thisTile, N,
     I               e2BufrRecSize,
     O               iBuf1Filled(N,bi,bj),    iBuf2Filled(N,bi,bj),
     O               e2Bufr1_RS(1,N,bi,bj,1), e2Bufr2_RS(1,N,bi,bj,1),
     I               array1(1-myOLw,1-myOLs,1,bi,bj),
     I               array2(1-myOLw,1-myOLs,1,bi,bj),
     I               i1Lo, i1Hi, j1Lo, j1Hi, k1Lo, k1Hi,
     I               i2Lo, i2Hi, j2Lo, j2Hi, k2Lo, k2Hi,
     O               e2_msgHandles(1,N,bi,bj),
     I               W2_myCommFlag(N,bi,bj), signOption, myThid )
        ENDDO
       ENDDO
      ENDDO

C     Wait until all threads finish filling buffer
      CALL BAR2( myThid )

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

#ifdef ALLOW_USE_MPI
      IF ( usingMPI ) THEN

      _BEGIN_MASTER( myThid )

C--   Send my data (in buffer, level 1) to target Process
      DO bj=1,nSy
       DO bi=1,nSx
        thisTile=W2_myTileList(bi,bj)
        nN=exch2_nNeighbours(thisTile)
        DO N=1,nN
C-    Skip the call if this is an internal exchange
         IF ( W2_myCommFlag(N,bi,bj) .EQ. 'M' ) THEN
          CALL EXCH2_SEND_RS2(
     I               thisTile, N,
     I               e2BufrRecSize,
     I               iBuf1Filled(N,bi,bj),    iBuf2Filled(N,bi,bj),
     I               e2Bufr1_RS(1,N,bi,bj,1), e2Bufr2_RS(1,N,bi,bj,1),
     O               e2_msgHandles(1,N,bi,bj),
     I               W2_myCommFlag(N,bi,bj), myThid )
         ENDIF
        ENDDO
       ENDDO
      ENDDO

C--   Receive data (in buffer, level 2) from source Process
      DO bj=1,nSy
       DO bi=1,nSx
        thisTile=W2_myTileList(bi,bj)
        nN=exch2_nNeighbours(thisTile)
        DO N=1,nN
C-    Skip the call if this is an internal exchange
         IF ( W2_myCommFlag(N,bi,bj) .EQ. 'M' ) THEN
          CALL EXCH2_GET_UV_BOUNDS(
     I               fieldCode, exchWidthX, updateCorners,
     I               thisTile, N,
     O               tIlo1, tIhi1, tJlo1, tJhi1,
     O               tIlo2, tIhi2, tJlo2, tJhi2,
     O               tiStride, tjStride,
     O               oIs1, oJs1, oIs2, oJs2,
     I               myThid )
          nri = 1 + (tIhi1-tIlo1)/tiStride
          nrj = 1 + (tJhi1-tJlo1)/tjStride
          iBufr1 = nri*nrj*myNz
          nri = 1 + (tIhi2-tIlo2)/tiStride
          nrj = 1 + (tJhi2-tJlo2)/tjStride
          iBufr2 = nri*nrj*myNz
C       Receive from neighbour N to fill buffer and later on the array
          CALL EXCH2_RECV_RS2(
     I               thisTile, N,
     I               e2BufrRecSize,
     I               iBufr1, iBufr2,
     I               e2Bufr1_RS(1,N,bi,bj,2), e2Bufr2_RS(1,N,bi,bj,2),
     I               W2_myCommFlag(N,bi,bj), myThid )
         ENDIF
        ENDDO
       ENDDO
      ENDDO

C--   Clear message handles/locks
      DO bj=1,nSy
       DO bi=1,nSx
        thisTile=W2_myTileList(bi,bj)
        nN=exch2_nNeighbours(thisTile)
        DO N=1,nN
C     Note: In a between process tile-tile data transport using
C           MPI the sender needs to clear an Isend wait handle here.
C           In a within process tile-tile data transport using true
C           shared address space/or direct transfer through commonly
C           addressable memory blocks the receiver needs to assert
C           that he has consumed the buffer the sender filled here.
         farTile=exch2_neighbourId(N,thisTile)
         IF     ( W2_myCommFlag(N,bi,bj) .EQ. 'M' ) THEN
          wHandle = e2_msgHandles(1,N,bi,bj)
          CALL MPI_Wait( wHandle, mpiStatus, mpiRc )
          wHandle = e2_msgHandles(2,N,bi,bj)
          CALL MPI_Wait( wHandle, mpiStatus, mpiRc )
         ELSEIF ( W2_myCommFlag(N,bi,bj) .EQ. 'P' ) THEN
         ELSE
         ENDIF
        ENDDO
       ENDDO
      ENDDO

      _END_MASTER( myThid )
C     Everyone waits until master-thread finishes receiving
      CALL BAR2( myThid )

      ENDIF
#endif /* ALLOW_USE_MPI */

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

C--   Extract from buffer (either from level 1 if local exch,
C                     or level 2 if coming from an other Proc)
      DO bj=myByLo(myThid), myByHi(myThid)
       DO bi=myBxLo(myThid), myBxHi(myThid)
        thisTile=W2_myTileList(bi,bj)
        nN=exch2_nNeighbours(thisTile)
        DO N=1,nN
#ifdef LOCAL_DBUG
          WRITE(errorMessageUnit,'(A,3I3,A,4I4,A,2I5)')
     &      'recv_0 bi,N=', bi,bj, N, ' , tI,J_lo,hi=',
     &          exch2_iLo(N,thisTile), exch2_iHi(N,thisTile),
     &          exch2_jLo(N,thisTile), exch2_jHi(N,thisTile)
#endif
          CALL EXCH2_GET_UV_BOUNDS(
     I               fieldCode, exchWidthX, updateCorners,
     I               thisTile, N,
     O               tIlo1, tIhi1, tJlo1, tJhi1,
     O               tIlo2, tIhi2, tJlo2, tJhi2,
     O               tiStride, tjStride,
     O               oIs1, oJs1, oIs2, oJs2,
     I               myThid )
#ifdef LOCAL_DBUG
          WRITE(errorMessageUnit,'(A,3I3,A,4I4,A,2I5)')
     &      'recv_1 bi,N=', bi,bj, N, ' , tI,J_lo,hi=',
     &      tIlo1, tIhi1, tJlo1, tJhi1
          WRITE(errorMessageUnit,'(A,3I3,A,4I4,A,2I5)')
     &      'recv_2 bi,N=', bi,bj, N, ' , tI,J_lo,hi=',
     &      tIlo2, tIhi2, tJlo2, tJhi2
#endif
          tKLo=1
          tKHi=myNz
          tKStride=1

C     From buffer, get my points
C     (tIlo:tIhi:tiStride,tJlo:tJhi,tJStride,tKlo:tKhi,tKStride) in "array1,2":
C     Note: when transferring data within a process:
C      o e2Bufr entry to read is entry associated with opposing send record
C      o e2_msgHandle entry to read is entry associated with opposing send record.
          CALL EXCH2_GET_RS2(
     I               tIlo1, tIhi1, tIlo2, tIhi2, tiStride,
     I               tJlo1, tJhi1, tJlo2, tJhi2, tjStride,
     I               tKlo, tKhi, tkStride,
     I               thisTile, N, bi, bj,
     I               e2BufrRecSize, W2_maxNeighbours, nSx, nSy,
     I               e2Bufr1_RS, e2Bufr2_RS,
     U               array1(1-myOLw,1-myOLs,1,bi,bj),
     U               array2(1-myOLw,1-myOLs,1,bi,bj),
     I               i1Lo, i1Hi, j1Lo, j1Hi, k1Lo, k1Hi,
     I               i2Lo, i2Hi, j2Lo, j2Hi, k2Lo, k2Hi,
     U               e2_msgHandles,
     I               W2_myCommFlag(N,bi,bj), myThid )
        ENDDO
       ENDDO
      ENDDO

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

CEH3 ;;; Local Variables: ***
CEH3 ;;; mode:fortran ***
CEH3 ;;; End: ***
