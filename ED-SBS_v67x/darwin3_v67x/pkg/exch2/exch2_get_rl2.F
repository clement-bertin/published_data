#include "CPP_EEOPTIONS.h"
#include "W2_OPTIONS.h"

CBOP 0
C !ROUTINE: EXCH2_GET_RL2

C !INTERFACE:
      SUBROUTINE EXCH2_GET_RL2 (
     I       tIlo1, tIhi1, tIlo2, tIhi2, tiStride,
     I       tJlo1, tJhi1, tJlo2, tJhi2, tjStride,
     I       tKlo, tKhi, tkStride,
     I       thisTile, nN, bi, bj,
     I       e2BufrRecSize, sizeNb, sizeBi, sizeBj,
     I       e2Bufr1_RL, e2Bufr2_RL,
     U       array1,
     U       array2,
     I       i1Lo, i1Hi, j1Lo, j1Hi, k1Lo, k1Hi,
     I       i2Lo, i2Hi, j2Lo, j2Hi, k2Lo, k2Hi,
     U       e2_msgHandles,
     I       commSetting, myThid )

C !DESCRIPTION:
C     Two components vector field Exchange:
C     Get from buffer exchanged data to fill in this tile-egde overlap region.

C !USES:
      IMPLICIT NONE

#include "SIZE.h"
#include "EEPARAMS.h"
#include "W2_EXCH2_SIZE.h"
#include "W2_EXCH2_TOPOLOGY.h"

C !INPUT/OUTPUT PARAMETERS:
C     === Routine arguments ===
C     tIlo1, tIhi1  :: index range in I that will be filled in target "array1"
C     tIlo2, tIhi2  :: index range in I that will be filled in target "array2"
C     tIstride      :: index step  in I that will be filled in target arrays
C     tJlo1, tJhi1  :: index range in J that will be filled in target "array1"
C     tJlo2, tJhi2  :: index range in J that will be filled in target "array2"
C     tJstride      :: index step  in J that will be filled in target arrays
C     tKlo, tKhi    :: index range in K that will be filled in target arrays
C     tKstride      :: index step  in K that will be filled in target arrays
C     oIs1, oJs1    :: I,J index offset in target "array1" to source connection
C     oIs2, oJs2    :: I,J index offset in target "array2" to source connection
C     thisTile      :: receiving tile Id. number
C     nN            :: Neighbour entry that we are processing
C     bi,bj         :: Indices of the receiving tile within this process
C                   ::  (used to select buffer slots that are allowed).
C     e2BufrRecSize :: Number of elements in each entry of e2Bufr[1,2]_RL
C     sizeNb        :: Second dimension of e2Bufr1_RL & e2Bufr2_RL
C     sizeBi        :: Third  dimension of e2Bufr1_RL & e2Bufr2_RL
C     sizeBj        :: Fourth dimension of e2Bufr1_RL & e2Bufr2_RL
C     e2Bufr1_RL    :: Data transport buffer array. This array is used in one of
C     e2Bufr2_RL    :: two ways. For PUT communication the entry in the buffer
C                   :: associated with the source for this receive (determined
C                   :: from the opposing_send index) is read.
C                   :: For MSG communication the entry in the buffer associated
C                   :: with this neighbor of this tile is used as a receive
C                   :: location for loading a linear stream of bytes.
C     array1        :: 1rst Component target array that this receive writes to.
C     array2        :: 2nd  Component target array that this receive writes to.
C     i1Lo, i1Hi    :: I coordinate bounds of target array1
C     j1Lo, j1Hi    :: J coordinate bounds of target array1
C     k1Lo, k1Hi    :: K coordinate bounds of target array1
C     i2Lo, i2Hi    :: I coordinate bounds of target array2
C     j2Lo, j2Hi    :: J coordinate bounds of target array2
C     k2Lo, k2Hi    :: K coordinate bounds of target array2
C     e2_msgHandles :: Synchronization and coordination data structure used to
C                   :: coordinate access to e2Bufr1_RL or to regulate message
C                   :: buffering. In PUT communication sender will increment
C                   :: handle entry once data is ready in buffer. Receiver will
C                   :: decrement handle once data is consumed from buffer.
C                   :: For MPI MSG communication MPI_Wait uses handle to check
C                   :: Isend has cleared. This is done in routine after receives.
C     commSetting   :: Mode of communication used to exchange with this neighbor
C     withSigns     :: Flag controlling whether vector field is signed.
C     myThid        :: my Thread Id. number

      INTEGER tIlo1, tIhi1, tIlo2, tIhi2, tiStride
      INTEGER tJlo1, tJhi1, tJlo2, tJhi2, tjStride
      INTEGER tKlo, tKhi, tkStride
      INTEGER i1Lo, i1Hi, j1Lo, j1Hi, k1Lo, k1Hi
      INTEGER i2Lo, i2Hi, j2Lo, j2Hi, k2Lo, k2Hi
      INTEGER thisTile, nN, bi, bj
      INTEGER e2BufrRecSize, sizeNb, sizeBi, sizeBj
      _RL     e2Bufr1_RL( e2BufrRecSize, sizeNb, sizeBi, sizeBj, 2 )
      _RL     e2Bufr2_RL( e2BufrRecSize, sizeNb, sizeBi, sizeBj, 2 )
      _RL     array1(i1Lo:i1Hi,j1Lo:j1Hi,k1Lo:k1Hi)
      _RL     array2(i2Lo:i2Hi,j2Lo:j2Hi,k2Lo:k2Hi)
      INTEGER e2_msgHandles( 2, sizeNb, sizeBi, sizeBj )
      CHARACTER commSetting
      INTEGER myThid
CEOP

C !LOCAL VARIABLES:
C     == Local variables ==
C     itl,jtl,ktl :: Loop counters (this tile)
C     soT    :: Source tile Id number
C     oNb    :: Opposing send record number
C     iBufr1 :: number of buffer-1 elements to transfer
C     iBufr2 :: number of buffer-2 elements to transfer
C     sNb    :: buffer(source) Neighbour index to get data from
C     sBi    :: buffer(source) local(to this Proc) Tile index to get data from
C     sBj    :: buffer(source) local(to this Proc) Tile index to get data from
C     sLv    :: buffer(source) level index to get data from
C     i,j    :: Loop counters

      INTEGER itl, jtl, ktl
      INTEGER soT
      INTEGER oNb
      INTEGER iBufr1, iBufr2
      INTEGER sNb, sBi, sBj, sLv
c     CHARACTER*(MAX_LEN_MBUF) msgBuf

      soT = exch2_neighbourId( nN, thisTile )
      oNb = exch2_opposingSend(nN, thisTile )

C     Handle receive end data transport according to communication mechanism between
C     source and target tile
      IF     ( commSetting .EQ. 'P' ) THEN

C      1 Need to check and spin on data ready assertion for multithreaded mode,
C        for now, ensure global sync using barrier.
C      2 get directly data from 1rst level buffer (sLv=1);

C     find the tile indices (local to this Proc) corresponding to
C      this source tile Id "soT" (note: this is saved in W2_tileIndex array)
       sLv = 1
       sNb = oNb
       sBi = W2_tileIndex(soT)
       sBj = 1 + (sBi-1)/sizeBi
       sBi = 1 + MOD(sBi-1,sizeBi)
#ifdef ALLOW_USE_MPI
      ELSEIF ( commSetting .EQ. 'M' ) THEN
       sLv = 2
       sBi = bi
       sBj = bj
       sNb = nN
#endif /* ALLOW_USE_MPI */
      ELSE
       STOP 'EXCH2_GET_RL2:: commSetting VALUE IS INVALID'
      ENDIF

      iBufr1=0
      DO ktl=tKlo,tKhi,tkStride
       DO jtl=tJLo1, tJHi1, tjStride
        DO itl=tILo1, tIHi1, tiStride
C     Read from e2Bufr1_RL(iBufr,sNb,sBi,sBj,sLv)
         iBufr1 = iBufr1+1
         array1(itl,jtl,ktl) = e2Bufr1_RL(iBufr1,sNb,sBi,sBj,sLv)
        ENDDO
       ENDDO
      ENDDO

      iBufr2=0
      DO ktl=tKlo,tKhi,tkStride
       DO jtl=tJLo2, tJHi2, tjStride
        DO itl=tILo2, tIHi2, tiStride
C     Read from e2Bufr2_RL(iBufr,sNb,sBi,sBj,sLv)
         iBufr2 = iBufr2+1
         array2(itl,jtl,ktl) = e2Bufr2_RL(iBufr2,sNb,sBi,sBj,sLv)
        ENDDO
       ENDDO
      ENDDO

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

CEH3 ;;; Local Variables: ***
CEH3 ;;; mode:fortran ***
CEH3 ;;; End: ***
