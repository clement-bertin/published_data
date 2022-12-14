#include "CPP_EEOPTIONS.h"
#include "W2_OPTIONS.h"

CBOP 0
C !ROUTINE: EXCH2_AD_GET_R82

C !INTERFACE:
      SUBROUTINE EXCH2_AD_GET_R82 (
     I       tIlo1, tIhi1, tIlo2, tIhi2, tiStride,
     I       tJlo1, tJhi1, tJlo2, tJhi2, tjStride,
     I       tKlo, tKhi, tkStride,
     I       thisTile, nN, bi, bj,
     I       e2BufrRecSize, sizeNb, sizeBi, sizeBj,
     O       iBufr1, iBufr2,
     O       e2Bufr1_R8, e2Bufr2_R8,
     U       array1,
     U       array2,
     I       i1Lo, i1Hi, j1Lo, j1Hi, k1Lo, k1Hi,
     I       i2Lo, i2Hi, j2Lo, j2Hi, k2Lo, k2Hi,
     U       e2_msgHandles,
     I       commSetting, myThid )

C !DESCRIPTION:
C---------------
C  AD: IMPORTANT: All comments (except AD:) are taken from the Forward S/R
C  AD:       and need to be interpreted in the reverse sense: put <-> get,
C  AD:       send <-> recv, source <-> target ...
C---------------
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
C     e2BufrRecSize :: Number of elements in each entry of e2Bufr[1,2]_R8
C     sizeNb        :: Second dimension of e2Bufr1_R8 & e2Bufr2_R8
C     sizeBi        :: Third  dimension of e2Bufr1_R8 & e2Bufr2_R8
C     sizeBj        :: Fourth dimension of e2Bufr1_R8 & e2Bufr2_R8
C     iBufr1        :: number of buffer-1 elements to transfer
C     iBufr2        :: number of buffer-2 elements to transfer
C     e2Bufr1_R8    :: Data transport buffer array. This array is used in one of
C     e2Bufr2_R8    :: two ways. For PUT communication the entry in the buffer
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
C                   :: coordinate access to e2Bufr1_R8 or to regulate message
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
      INTEGER iBufr1, iBufr2
      _R8     e2Bufr1_R8( e2BufrRecSize, sizeNb, sizeBi, sizeBj, 2 )
      _R8     e2Bufr2_R8( e2BufrRecSize, sizeNb, sizeBi, sizeBj, 2 )
      _R8     array1(i1Lo:i1Hi,j1Lo:j1Hi,k1Lo:k1Hi)
      _R8     array2(i2Lo:i2Hi,j2Lo:j2Hi,k2Lo:k2Hi)
      INTEGER e2_msgHandles( 2, sizeNb, sizeBi, sizeBj )
      CHARACTER commSetting
      INTEGER myThid
CEOP

C !LOCAL VARIABLES:
C     == Local variables ==
C     itl,jtl,ktl :: Loop counters (this tile)
C     soT    :: Source tile Id number
C     oNb    :: Opposing send record number
C     sNb    :: buffer(source) Neighbour index to get data from
C     sBi    :: buffer(source) local(to this Proc) Tile index to get data from
C     sBj    :: buffer(source) local(to this Proc) Tile index to get data from
C     sLv    :: buffer(source) level index to get data from
C     i,j    :: Loop counters

      INTEGER itl, jtl, ktl
      INTEGER soT
      INTEGER oNb
      INTEGER sNb, sBi, sBj, sLv
      INTEGER iLoc
      CHARACTER*(MAX_LEN_MBUF) msgBuf

      soT = exch2_neighbourId( nN, thisTile )
      oNb = exch2_opposingSend(nN, thisTile )

C     Handle receive end data transport according to communication mechanism between
C     source and target tile
      IF     ( commSetting .EQ. 'P' ) THEN
C  AD: Need to check that buffer synchronisation token is decremented
C  AD: before filling buffer.

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
       STOP 'EXCH2_AD_GET_R82:: commSetting VALUE IS INVALID'
      ENDIF

      iBufr1=0
      DO ktl=tKlo,tKhi,tkStride
       DO jtl=tJLo1, tJHi1, tjStride
        DO itl=tILo1, tIHi1, tiStride
C     Read from e2Bufr1_R8(iBufr,sNb,sBi,sBj,sLv)
         iBufr1 = iBufr1+1
#ifdef W2_USE_E2_SAFEMODE
         iLoc = MIN( iBufr1, e2BufrRecSize )
#else
         iLoc = iBufr1
#endif
         e2Bufr1_R8(iLoc,sNb,sBi,sBj,sLv) = array1(itl,jtl,ktl)
         array1(itl,jtl,ktl) = 0.
        ENDDO
       ENDDO
      ENDDO
      IF ( iBufr1 .GT. e2BufrRecSize ) THEN
        WRITE(msgBuf,'(2A,I9,A,I9)') 'EXCH2_AD_GET_R82:',
     &   ' iBufr1=', iBufr1, ' exceeds E2BUFR size=', e2BufrRecSize
        CALL PRINT_ERROR ( msgBuf, myThid )
        STOP 'ABNORMAL END: S/R EXCH2_AD_GET_R82 (iBufr1 over limit)'
      ENDIF

      iBufr2=0
      DO ktl=tKlo,tKhi,tkStride
       DO jtl=tJLo2, tJHi2, tjStride
        DO itl=tILo2, tIHi2, tiStride
C     Read from e2Bufr2_R8(iBufr,sNb,sBi,sBj,sLv)
         iBufr2 = iBufr2+1
#ifdef W2_USE_E2_SAFEMODE
         iLoc = MIN( iBufr2, e2BufrRecSize )
#else
         iLoc = iBufr2
#endif
         e2Bufr2_R8(iLoc,sNb,sBi,sBj,sLv) = array2(itl,jtl,ktl)
         array2(itl,jtl,ktl) = 0.
        ENDDO
       ENDDO
      ENDDO
      IF ( iBufr2 .GT. e2BufrRecSize ) THEN
        WRITE(msgBuf,'(2A,I9,A,I9)') 'EXCH2_AD_GET_R82:',
     &   ' iBufr2=', iBufr2, ' exceeds E2BUFR size=', e2BufrRecSize
        CALL PRINT_ERROR ( msgBuf, myThid )
        STOP 'ABNORMAL END: S/R EXCH2_AD_GET_R82 (iBufr2 over limit)'
      ENDIF

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

CEH3 ;;; Local Variables: ***
CEH3 ;;; mode:fortran ***
CEH3 ;;; End: ***
