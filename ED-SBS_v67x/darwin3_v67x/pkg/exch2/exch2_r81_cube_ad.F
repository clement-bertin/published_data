#include "CPP_EEOPTIONS.h"

CBOP
C     !ROUTINE: EXCH_R8_CUBE_AD

C     !INTERFACE:
      SUBROUTINE EXCH2_R81_CUBE_AD(
     U            array,
     I            signOption, fieldCode,
     I            myOLw, myOLe, myOLs, myOLn, myNz,
     I            exchWidthX, exchWidthY,
     I            cornerMode, myThid )

C     !DESCRIPTION:
C     Scalar field (1 component) AD-Exchange:
C     Tile-edge overlap-region of a 1 component scalar field is added to
C     corresponding near-edge interior data point and then zero out.

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
C     array       :: Array with edges to exchange.
C     signOption  :: Flag controlling whether field sign depends on orientation
C                 :: (signOption not yet implemented but needed for SM exch)
C     fieldCode   :: field code (position on staggered grid)
C     myOLw,myOLe :: West and East overlap region sizes.
C     myOLs,myOLn :: South and North overlap region sizes.
C     exchWidthX  :: Width of data regi exchanged in X.
C     exchWidthY  :: Width of data region exchanged in Y.
C     cornerMode  :: halo-corner-region treatment: update/ignore corner region
C     myThid      :: Thread number of this instance of S/R EXCH...

      INTEGER myOLw, myOLe, myOLs, myOLn, myNz
      _R8 array(1-myOLw:sNx+myOLe,
     &          1-myOLs:sNy+myOLn,
     &          myNZ, nSx, nSy)
      LOGICAL signOption
      CHARACTER*2 fieldCode
      INTEGER exchWidthX
      INTEGER exchWidthY
      INTEGER cornerMode
      INTEGER myThid

C     !LOCAL VARIABLES:
C     e2_msgHandles :: Synchronization and coordination data structure used to
C                   :: coordinate access to e2Bufr1_R8 or to regulate message
C                   :: buffering. In PUT communication sender will increment
C                   :: handle entry once data is ready in buffer. Receiver will
C                   :: decrement handle once data is consumed from buffer.
C                   :: For MPI MSG communication MPI_Wait uses handle to check
C                   :: Isend has cleared. This is done in routine after receives.
C     note: a) current implementation does not use e2_msgHandles for communication
C              between threads: all-threads barriers are used (see CNH note below).
C              For a 2-threads synchro communication (future version),
C              e2_msgHandles should be shared (in common block, moved to BUFFER.h)
C           b) 1rst dim=2 so that it could be used also by exch2_rx2_cube.
      INTEGER bi, bj
C     Variables for working through W2 topology
      INTEGER e2_msgHandles( 2, W2_maxNeighbours, nSx, nSy )
      INTEGER thisTile, farTile, N, nN, oN
      INTEGER tIlo, tIhi, tJlo, tJhi, tKlo, tKhi
      INTEGER tIStride, tJStride, tKStride
      INTEGER i1Lo, i1Hi, j1Lo, j1Hi, k1Lo, k1Hi
      LOGICAL updateCorners

#ifdef ALLOW_USE_MPI
      INTEGER iBufr, nri, nrj
C     MPI stuff (should be in a routine call)
      INTEGER mpiStatus(MPI_STATUS_SIZE)
      INTEGER mpiRc
      INTEGER wHandle
#endif
CEOP

      updateCorners = cornerMode .EQ. EXCH_UPDATE_CORNERS
C-    Tile size of array to exchange:
      i1Lo  = 1-myOLw
      i1Hi  = sNx+myOLe
      j1Lo  = 1-myOLs
      j1Hi  = sNy+myOLn
      k1Lo  = 1
      k1Hi  = myNz

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

C     Prevent anyone to access shared buffer while an other thread modifies it
      CALL BAR2( myThid )

C--    Extract from buffer (either from level 1 if local exch,
C                           or level 2 if coming from an other Proc)
C  AD: = fill buffer from my-tile-edge overlap-region, level 1 or 2 depending
C  AD:   on local (to this Proc) or remote Proc tile destination
      DO bj=myByLo(myThid), myByHi(myThid)
       DO bi=myBxLo(myThid), myBxHi(myThid)
        thisTile=W2_myTileList(bi,bj)
        nN=exch2_nNeighbours(thisTile)
        DO N=1,nN
          CALL EXCH2_GET_SCAL_BOUNDS(
     I               fieldCode, exchWidthX, updateCorners,
     I               thisTile, N,
     O               tIlo, tiHi, tjLo, tjHi,
     O               tiStride, tjStride,
     I               myThid )
          tKLo=1
          tKHi=myNz
          tKStride=1

C      From buffer, get my points
C      (tIlo:tIhi:tiStride,tJlo:tJhi,tJStride,tKlo:tKhi,tKStride) in "array":
C      Note: when transferring data within a process:
C       o e2Bufr entry to read is entry associated with opposing send record
C       o e2_msgHandle entry to read is entry associated with opposing send record.
          CALL EXCH2_AD_GET_R81(
     I               tIlo, tIhi, tiStride,
     I               tJlo, tJhi, tjStride,
     I               tKlo, tKhi, tkStride,
     I               thisTile, N, bi, bj,
     I               e2BufrRecSize, W2_maxNeighbours, nSx, nSy,
     O               iBuf1Filled(N,bi,bj),
     O               e2Bufr1_R8,
     U               array(1-myOLw,1-myOLs,1,bi,bj),
     I               i1Lo, i1Hi, j1Lo, j1Hi, k1Lo, k1Hi,
     U               e2_msgHandles,
     I               W2_myCommFlag(N,bi,bj), myThid )
        ENDDO
       ENDDO
      ENDDO

C     Wait until all threads finish filling buffer
      CALL BAR2( myThid )

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

#ifdef ALLOW_USE_MPI
      IF ( usingMPI ) THEN
C  AD: all MPI part is acting on buffer and is identical to forward code,
C  AD: except a) the buffer level: send from lev.2, receive into lev.1
C  AD:        b) the length of transferred buffer (<- match the ad_put/ad_get)

      _BEGIN_MASTER( myThid )

C--   Send my data (in buffer, level 2) to target Process
      DO bj=1,nSy
       DO bi=1,nSx
        thisTile=W2_myTileList(bi,bj)
        nN=exch2_nNeighbours(thisTile)
        DO N=1,nN
C-    Skip the call if this is an internal exchange
         IF ( W2_myCommFlag(N,bi,bj) .EQ. 'M' ) THEN
          CALL EXCH2_SEND_R81(
     I               thisTile, N,
     I               e2BufrRecSize,
     I               iBuf1Filled(N,bi,bj),
     I               e2Bufr1_R8(1,N,bi,bj,2),
     O               e2_msgHandles(1,N,bi,bj),
     I               W2_myCommFlag(N,bi,bj), myThid )
         ENDIF
        ENDDO
       ENDDO
      ENDDO

C--   Receive data (in buffer, level 1) from source Process
      DO bj=1,nSy
       DO bi=1,nSx
        thisTile=W2_myTileList(bi,bj)
        nN=exch2_nNeighbours(thisTile)
        DO N=1,nN
C-    Skip the call if this is an internal exchange
         IF ( W2_myCommFlag(N,bi,bj) .EQ. 'M' ) THEN
          farTile=exch2_neighbourId(N,thisTile)
          oN = exch2_opposingSend(N,thisTile)
          CALL EXCH2_GET_SCAL_BOUNDS(
     I               fieldCode, exchWidthX, updateCorners,
     I               farTile, oN,
     O               tIlo, tiHi, tjLo, tjHi,
     O               tiStride, tjStride,
     I               myThid )
          nri = 1 + (tIhi-tIlo)/tiStride
          nrj = 1 + (tJhi-tJlo)/tjStride
          iBufr = nri*nrj*myNz
C       Receive from neighbour N to fill buffer and later on the array
          CALL EXCH2_RECV_R81(
     I               thisTile, N,
     I               e2BufrRecSize,
     I               iBufr,
     O               e2Bufr1_R8(1,N,bi,bj,1),
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
c        farTile=exch2_neighbourId(N,thisTile)
         IF     ( W2_myCommFlag(N,bi,bj) .EQ. 'M' ) THEN
          wHandle = e2_msgHandles(1,N,bi,bj)
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

C--   Post sends into buffer (buffer level 1):
C- AD: = get exch-data from buffer (level 1), formerly in source tile
C  AD:   overlap region, and add to my tile near-Edge interior
      DO bj=myByLo(myThid), myByHi(myThid)
       DO bi=myBxLo(myThid), myBxHi(myThid)
        thisTile=W2_myTileList(bi,bj)
        nN=exch2_nNeighbours(thisTile)
        DO N=1,nN
          farTile=exch2_neighbourId(N,thisTile)
          oN = exch2_opposingSend(N,thisTile)
          CALL EXCH2_GET_SCAL_BOUNDS(
     I               fieldCode, exchWidthX, updateCorners,
     I               farTile, oN,
     O               tIlo, tiHi, tjLo, tjHi,
     O               tiStride, tjStride,
     I               myThid )
          tKLo=1
          tKHi=myNz
          tKStride=1
C-    Put my points in buffer for neighbour N to fill points
C     (tIlo:tIhi:tiStride,tJlo:tJhi,tJStride,tKlo:tKhi,tKStride)
C     in its copy of "array".
          CALL EXCH2_AD_PUT_R81(
     I               tIlo, tIhi, tiStride,
     I               tJlo, tJhi, tjStride,
     I               tKlo, tKhi, tkStride,
     I               thisTile, N,
     I               e2BufrRecSize,
     I               e2Bufr1_R8(1,N,bi,bj,1),
     U               array(1-myOLw,1-myOLs,1,bi,bj),
     I               i1Lo, i1Hi, j1Lo, j1Hi, k1Lo, k1Hi,
     O               e2_msgHandles(1,N,bi,bj),
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
