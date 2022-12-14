#include "CPP_EEOPTIONS.h"

CBOP

C     !ROUTINE: EXCH1_R8

C     !INTERFACE:
      SUBROUTINE EXCH1_R8(
     U                 array,
     I                 myOLw, myOLe, myOLs, myOLn, myNz,
     I                 exchWidthX, exchWidthY,
     I                 cornerMode, myThid )

C     !DESCRIPTION:
C     *==========================================================*
C     | SUBROUTINE EXCH1_R8
C     | o Control forward-mode edge exchanges for R8 array.
C     *==========================================================*
C     | Controlling routine for exchange of XY edges of an array
C     | distributed in X and Y. The routine interfaces to
C     | communication routines that can use messages passing
C     | exchanges, put type exchanges or get type exchanges.
C     |  This allows anything from MPI to raw memory channel to
C     | memmap segments to be used as a inter-process and/or
C     | inter-thread communiation and synchronisation
C     | mechanism.
C     | Notes --
C     | 1. Some low-level mechanisms such as raw memory-channel
C     | or SGI/CRAY shmem put do not have direct Fortran bindings
C     | and are invoked through C stub routines.
C     | 2. Although this routine is fairly general but it does
C     | require nSx and nSy are the same for all innvocations.
C     | There are many common data structures ( myByLo,
C     | westCommunicationMode, mpiIdW etc... ) tied in with
C     | (nSx,nSy). To support arbitray nSx and nSy would require
C     | general forms of these.
C     | 3. R8 arrays are used to generate code for both _RL and
C     | _RS forms.
C     *==========================================================*

C     !USES:
      IMPLICIT NONE

C     == Global data ==
#include "SIZE.h"
#include "EEPARAMS.h"
#include "EXCH.h"

C     !INPUT/OUTPUT PARAMETERS:
C     == Routine arguments ==
C     array       :: Array with edges to exchange.
C     myOLw,myOLe :: West  and East  overlap region sizes.
C     myOLs,myOLn :: South and North overlap region sizes.
C     exchWidthX  :: Width of data region exchanged in X.
C     exchWidthY  :: Width of data region exchanged in Y.
C                    Note --
C                    1. In theory one could have a send width and
C                    a receive width for each face of each tile. The only
C                    restriction would be that the send width of one
C                    face should equal the receive width of the sent to
C                    tile face. Dont know if this would be useful. I
C                    have left it out for now as it requires additional
C                    bookeeping.
C     cornerMode  :: Flag indicating whether corner updates are needed.
C     myThid      :: my Thread Id number

      INTEGER myOLw, myOLe, myOLs, myOLn, myNz
      _R8     array( 1-myOLw:sNx+myOLe,
     &               1-myOLs:sNy+myOLn,
     &               myNz, nSx, nSy )
      INTEGER exchWidthX
      INTEGER exchWidthY
      INTEGER cornerMode
      INTEGER myThid

C     !LOCAL VARIABLES:
C     == Local variables ==
C     theSimulationMode :: Holds working copy of simulation mode
C     theCornerMode     :: Holds working copy of corner mode
C     i,j,k,bi,bj       :: Loop counters
      INTEGER theSimulationMode
      INTEGER theCornerMode
      INTEGER i,j,k,bi,bj
CEOP

      theSimulationMode = FORWARD_SIMULATION
      theCornerMode     = cornerMode

C--   Error checks
      IF ( exchWidthX .GT. myOLw   )
     &  STOP ' S/R EXCH1_R8: exchWidthX .GT. myOLw'
      IF ( exchWidthX .GT. myOLe   )
     &  STOP ' S/R EXCH1_R8: exchWidthX .GT. myOLe'
      IF ( exchWidthY .GT. myOLs   )
     &  STOP ' S/R EXCH1_R8: exchWidthY .GT. myOLs'
      IF ( exchWidthY .GT. myOLn   )
     &  STOP ' S/R EXCH1_R8: exchWidthY .GT. myOLn'
      IF ( myOLw      .GT. MAX_OLX_EXCH )
     &  STOP ' S/R EXCH1_R8: myOLw .GT. MAX_OLX_EXCH'
      IF ( myOLe      .GT. MAX_OLX_EXCH )
     &  STOP ' S/R EXCH1_R8: myOLe .GT. MAX_OLX_EXCH'
      IF ( myOLn      .GT. MAX_OLY_EXCH )
     &  STOP ' S/R EXCH1_R8: myOLn .GT. MAX_OLY_EXCH'
      IF ( myOLs      .GT. MAX_OLY_EXCH )
     &  STOP ' S/R EXCH1_R8: myOLs .GT. MAX_OLY_EXCH'
      IF ( myNz       .GT. MAX_NR_EXCH  )
     &  STOP ' S/R EXCH1_R8: myNz  .GT. MAX_NR_EXCH '
      IF (       theCornerMode .NE. EXCH_IGNORE_CORNERS
     &     .AND. theCornerMode .NE. EXCH_UPDATE_CORNERS
     &   ) STOP ' S/R EXCH1_R8: Unrecognised cornerMode '

C--   Cycle edge buffer level
      CALL EXCH_CYCLE_EBL( myThid )

      IF ( theSimulationMode .EQ. REVERSE_SIMULATION ) THEN

       IF ( Nx .EQ. 1 ) THEN
C      Special case for zonal average model i.e. case where Nx == 1
C      In this case a reverse mode exchange simply add values from all i <> 1
C      to i=1 element and reset to zero.
         DO bj=myByLo(myThid),myByHi(myThid)
          DO bi=myBxLo(myThid),myBxHi(myThid)
           DO k = 1,myNz
            DO j = 1-myOLs,sNy+myOLn
             DO i = 1-myOLw,0
              array(1,j,k,bi,bj) = array(1,j,k,bi,bj)
     &                           + array(i,j,k,bi,bj)
              array(i,j,k,bi,bj) = 0.
             ENDDO
             DO i = sNx+1,sNx+myOLe
              array(1,j,k,bi,bj) = array(1,j,k,bi,bj)
     &                           + array(i,j,k,bi,bj)
              array(i,j,k,bi,bj) = 0.
             ENDDO
            ENDDO
           ENDDO
          ENDDO
         ENDDO
       ENDIF

       IF ( Ny .EQ. 1 ) THEN
C      Special case for X-slice domain i.e. case where Ny == 1
C      In this case a reverse mode exchange simply add values from all j <> 1
C      to j=1 element and reset to zero.
         DO bj=myByLo(myThid),myByHi(myThid)
          DO bi=myBxLo(myThid),myBxHi(myThid)
           DO k = 1,myNz
            DO j = 1-myOLs,0
             DO i = 1-myOLw,sNx+myOLe
              array(i,1,k,bi,bj) = array(i,1,k,bi,bj)
     &                           + array(i,j,k,bi,bj)
              array(i,j,k,bi,bj) = 0.
             ENDDO
            ENDDO
            DO j = sNy+1,sNy+myOLn
             DO i = 1-myOLw,sNx+myOLe
              array(i,1,k,bi,bj) = array(i,1,k,bi,bj)
     &                           + array(i,j,k,bi,bj)
              array(i,j,k,bi,bj) = 0.
             ENDDO
            ENDDO
           ENDDO
          ENDDO
         ENDDO
       ENDIF

C--   end of special cases of forward exch
      ENDIF

      IF ( theSimulationMode .EQ. FORWARD_SIMULATION ) THEN
C--     "Put" east and west edges.
        CALL EXCH_R8_SEND_PUT_X( array,
     I              myOLw, myOLe, myOLs, myOLn, myNz,
     I              exchWidthX, exchWidthY,
     I              theSimulationMode, theCornerMode, myThid )
C--     If corners are important then sync and update east and west edges
C--     before doing north and south exchanges.
        IF ( theCornerMode .EQ. EXCH_UPDATE_CORNERS ) THEN
         CALL EXCH_R8_RECV_GET_X( array,
     I              myOLw, myOLe, myOLs, myOLn, myNz,
     I              exchWidthX, exchWidthY,
     I              theSimulationMode, theCornerMode, myThid )
        ENDIF
C       "Put" north and south edges.
        CALL EXCH_R8_SEND_PUT_Y( array,
     I              myOLw, myOLe, myOLs, myOLn, myNz,
     I              exchWidthX, exchWidthY,
     I              theSimulationMode, theCornerMode, myThid )
C--     Sync and update north, south (and east, west if corner updating
C--     not active).
        IF ( theCornerMode .NE. EXCH_UPDATE_CORNERS ) THEN
         CALL EXCH_R8_RECV_GET_X( array,
     I              myOLw, myOLe, myOLs, myOLn, myNz,
     I              exchWidthX, exchWidthY,
     I              theSimulationMode, theCornerMode, myThid )
        ENDIF
        CALL EXCH_R8_RECV_GET_Y( array,
     I             myOLw, myOLe, myOLs, myOLn, myNz,
     I             exchWidthX, exchWidthY,
     I             theSimulationMode, theCornerMode, myThid )
      ENDIF

      IF ( theSimulationMode .EQ. REVERSE_SIMULATION ) THEN
C       "Put" north and south edges.
        CALL EXCH_R8_SEND_PUT_Y( array,
     I              myOLw, myOLe, myOLs, myOLn, myNz,
     I              exchWidthX, exchWidthY,
     I              theSimulationMode, theCornerMode, myThid )
C--     If corners are important then sync and update east and west edges
C--     before doing north and south exchanges.
        IF ( theCornerMode .EQ. EXCH_UPDATE_CORNERS ) THEN
         CALL EXCH_R8_RECV_GET_Y( array,
     I              myOLw, myOLe, myOLs, myOLn, myNz,
     I              exchWidthX, exchWidthY,
     I              theSimulationMode, theCornerMode, myThid )
        ENDIF
C--     "Put" east and west edges.
        CALL EXCH_R8_SEND_PUT_X( array,
     I              myOLw, myOLe, myOLs, myOLn, myNz,
     I              exchWidthX, exchWidthY,
     I              theSimulationMode, theCornerMode, myThid )
C--     Sync and update east, west (and north, south if corner updating
C--     not active).
        IF ( theCornerMode .NE. EXCH_UPDATE_CORNERS ) THEN
         CALL EXCH_R8_RECV_GET_Y( array,
     I              myOLw, myOLe, myOLs, myOLn, myNz,
     I              exchWidthX, exchWidthY,
     I              theSimulationMode, theCornerMode, myThid )
        ENDIF
        CALL EXCH_R8_RECV_GET_X( array,
     I             myOLw, myOLe, myOLs, myOLn, myNz,
     I             exchWidthX, exchWidthY,
     I             theSimulationMode, theCornerMode, myThid )
      ENDIF

      IF ( theSimulationMode .EQ. FORWARD_SIMULATION ) THEN

       IF ( Nx .EQ. 1 ) THEN
C      Special case for zonal average model i.e. case where Nx == 1
C      In this case a forward mode exchange simply sets array to
C      the i=1 value for all i.
         DO bj=myByLo(myThid),myByHi(myThid)
          DO bi=myBxLo(myThid),myBxHi(myThid)
           DO k = 1,myNz
            DO j = 1-myOLs,sNy+myOLn
             DO i = 1-myOLw,sNx+myOLe
              array(i,j,k,bi,bj) = array(1,j,k,bi,bj)
             ENDDO
            ENDDO
           ENDDO
          ENDDO
         ENDDO
       ENDIF

       IF ( Ny .EQ. 1 ) THEN
C      Special case for X-slice domain i.e. case where Ny == 1
C      In this case a forward mode exchange simply sets array to
C      the j=1 value for all j.
         DO bj=myByLo(myThid),myByHi(myThid)
          DO bi=myBxLo(myThid),myBxHi(myThid)
           DO k = 1,myNz
            DO j = 1-myOLs,sNy+myOLn
             DO i = 1-myOLw,sNx+myOLe
              array(i,j,k,bi,bj) = array(i,1,k,bi,bj)
             ENDDO
            ENDDO
           ENDDO
          ENDDO
         ENDDO
       ENDIF

C--    end of special cases of forward exch
      ENDIF

      RETURN
      END
