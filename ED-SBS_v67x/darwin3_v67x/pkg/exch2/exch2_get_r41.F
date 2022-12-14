#include "CPP_EEOPTIONS.h"
#include "W2_OPTIONS.h"

CBOP 0
C !ROUTINE: EXCH2_GET_R41

C !INTERFACE:
      SUBROUTINE EXCH2_GET_R41(
     I       tIlo, tIhi, tiStride,
     I       tJlo, tJhi, tjStride,
     I       tKlo, tKhi, tkStride,
     I       thisTile, nN, bi, bj,
     I       e2BufrRecSize, sizeNb, sizeBi, sizeBj,
     I       e2Bufr1_R4,
     U       array,
     I       i1Lo, i1Hi, j1Lo, j1Hi, k1Lo, k1Hi,
     U       e2_msgHandles,
     I       commSetting, myThid )

C !DESCRIPTION:
C     Scalar field (1 component) Exchange:
C     Get from buffer exchanged data to fill in this tile-egde overlap region.

C !USES:
      IMPLICIT NONE

#include "SIZE.h"
#include "EEPARAMS.h"
#include "W2_EXCH2_SIZE.h"
#include "W2_EXCH2_TOPOLOGY.h"

C !INPUT/OUTPUT PARAMETERS:
C     === Routine arguments ===
C     tIlo,tIhi     :: index range in I that will be filled in target "array"
C     tIstride      :: index step  in I that will be filled in target "array"
C     tJlo,tJhi     :: index range in J that will be filled in target "array"
C     tJstride      :: index step  in J that will be filled in target "array"
C     tKlo,tKhi     :: index range in K that will be filled in target "array"
C     tKstride      :: index step  in K that will be filled in target "array"
C     thisTile      :: receiving tile Id. number
C     bi,bj         :: Indices of the receiving tile within this process
C                   ::  (used to select buffer slots that are allowed).
C     nN            :: Neighbour entry that we are processing
C     e2BufrRecSize :: Number of elements in each entry of e2Bufr1_R4
C     sizeNb        :: Second dimension of e2Bufr1_R4
C     sizeBi        :: Third  dimension of e2Bufr1_R4
C     sizeBj        :: Fourth dimension of e2Bufr1_R4
C     e2Bufr1_R4    :: Data transport buffer array. This array is used in one of
C                   :: two ways. For PUT communication the entry in the buffer
C                   :: associated with the source for this receive (determined
C                   :: from the opposing_send index) is read.
C                   :: For MSG communication the entry in the buffer associated
C                   :: with this neighbor of this tile is used as a receive
C                   :: location for loading a linear stream of bytes.
C     array         :: Target array that this receive writes to.
C     i1Lo, i1Hi    :: I coordinate bounds of target array
C     j1Lo, j1Hi    :: J coordinate bounds of target array
C     k1Lo, k1Hi    :: K coordinate bounds of target array
C     e2_msgHandles :: Synchronization and coordination data structure used to
C                   :: coordinate access to e2Bufr1_R4 or to regulate message
C                   :: buffering. In PUT communication sender will increment
C                   :: handle entry once data is ready in buffer. Receiver will
C                   :: decrement handle once data is consumed from buffer.
C                   :: For MPI MSG communication MPI_Wait uses handle to check
C                   :: Isend has cleared. This is done in routine after receives.
C     commSetting   :: Mode of communication used to exchange with this neighbor
C     myThid        :: my Thread Id. number

      INTEGER tILo, tIHi, tiStride
      INTEGER tJLo, tJHi, tjStride
      INTEGER tKLo, tKHi, tkStride
      INTEGER i1Lo, i1Hi, j1Lo, j1Hi, k1Lo, k1Hi
      INTEGER thisTile, nN, bi, bj
      INTEGER e2BufrRecSize, sizeNb, sizeBi, sizeBj
      _R4     e2Bufr1_R4( e2BufrRecSize, sizeNb, sizeBi, sizeBj, 2 )
      _R4     array(i1Lo:i1Hi,j1Lo:j1Hi,k1Lo:k1Hi)
      INTEGER e2_msgHandles( 2, sizeNb, sizeBi, sizeBj )
      CHARACTER commSetting
      INTEGER myThid
CEOP

C !LOCAL VARIABLES:
C     == Local variables ==
C     itl,jtl,ktl :: Loop counters (this tile)
C     soT    :: Source tile Id number
C     oNb    :: Opposing send record number
C     iBufr  :: Buffer counter
C     sNb    :: buffer (source) Neighbour index to get data from
C     sBi    :: buffer (source) Tile  index (for this Proc) to get data from
C     sBj    :: buffer (source) Tile  index (for this Proc) to get data from
C     sLv    :: buffer (source) level index to get data from
C     i,j    :: Loop counters
      INTEGER itl, jtl, ktl
      INTEGER soT
      INTEGER oNb
      INTEGER iBufr
      INTEGER sNb, sBi, sBj, sLv
c     CHARACTER*(MAX_LEN_MBUF) msgBuf

      soT = exch2_neighbourId( nN, thisTile )
      oNb = exch2_opposingSend(nN, thisTile )

C     Handle receive end data transport according to communication mechanism
C     between source and target tile
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
       STOP 'EXCH2_GET_R41:: commSetting VALUE IS INVALID'
      ENDIF

      iBufr = 0
      DO ktl=tKlo,tKhi,tKStride
       DO jtl=tJLo, tJHi, tjStride
        DO itl=tILo, tIHi, tiStride
C     Read from e2Bufr1_R4(iBufr,sNb,sBi,sBj,sLv)
         iBufr = iBufr+1
         array(itl,jtl,ktl) = e2Bufr1_R4(iBufr,sNb,sBi,sBj,sLv)
        ENDDO
       ENDDO
      ENDDO

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

CEH3 ;;; Local Variables: ***
CEH3 ;;; mode:fortran ***
CEH3 ;;; End: ***
