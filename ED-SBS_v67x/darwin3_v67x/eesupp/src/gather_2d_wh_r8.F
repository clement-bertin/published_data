#include "PACKAGES_CONFIG.h"
#include "CPP_EEOPTIONS.h"

CBOP
C !ROUTINE: GATHER_2D_WH_R8
C !INTERFACE:
      SUBROUTINE GATHER_2D_WH_R8(
     O                  gloBuff,
     I                  procBuff,
     I                  myThid )
C !DESCRIPTION:
C     Gather elements, including halos, of a global 2-D array from all mpi processes to process 0.
C     Note: done by Master-Thread ; might need barrier calls before and after
C           this S/R call.

C     !USES:
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "EESUPPORT.h"

C     !INPUT/OUTPUT PARAMETERS:
C gloBuff   ( _R8 ) :: full-domain 2D IO-buffer array             (Output)
C procBuff  ( _R8 ) :: proc-domain 2D IO-buffer array             (Input)
C myThid   (integer):: my Thread Id number

C     sNxWh :: x tile size with halo included
C     sNyWh :: y tile size with halo included
C     pocNyWh :: processor sum of sNyWh
C     gloNyWh :: global sum of sNyWh
      INTEGER sNxWh
      INTEGER sNyWh
      INTEGER procNyWh
      INTEGER gloNyWh
      PARAMETER ( sNxWh = sNx+2*Olx )
      PARAMETER ( sNyWh = sNy+2*Oly )
      PARAMETER ( procNyWh = sNyWh*nSy*nSx )
      PARAMETER ( gloNyWh = procNyWh*nPy*nPx )

      _R8     gloBuff(sNxWh,gloNyWh)
      _R8     procBuff(sNxWh,procNyWh)
      INTEGER myThid
CEOP

C !LOCAL VARIABLES:
      INTEGER i,j
#ifdef ALLOW_USE_MPI
      INTEGER jj, np, np0
      _R8     temp(sNxWh,gloNyWh)
      INTEGER istatus(MPI_STATUS_SIZE), ierr
      INTEGER lbuff, idest, itag, ready_to_receive
#endif /* ALLOW_USE_MPI */

      _BEGIN_MASTER( myThid )

      IF( myProcId .EQ. 0 ) THEN
C--   Process 0 fills-in its local data

c        DO j=1,gloNyWh
c          DO i=1,sNxWh
c            gloBuff(i,j) = 0.
c          ENDDO
c        ENDDO

        DO j=1,procNyWh
          DO i=1,sNxWh
            gloBuff(i,j) = procBuff(i,j)
          ENDDO
        ENDDO

C-    end if myProcId = 0
      ENDIF

#ifdef ALLOW_USE_MPI

      lbuff = sNxWh*procNyWh
      idest = 0
      itag  = 0
      ready_to_receive = 0

      IF( mpiMyId .EQ. 0 ) THEN

C--   Process 0 polls and receives data from each process in turn
        DO np = 2, numberOfProcs
         np0 = np - 1
#ifndef DISABLE_MPI_READY_TO_RECEIVE
         CALL MPI_SEND (ready_to_receive, 1, MPI_INTEGER,
     &           np0, itag, MPI_COMM_MODEL, ierr)
#endif
         CALL MPI_RECV (temp, lbuff, _MPI_TYPE_R8,
     &           np0, itag, MPI_COMM_MODEL, istatus, ierr)

         DO j=1,procNyWh
          DO i=1,sNxWh
           jj=j+procNyWh*(np-1)
           gloBuff(i,jj) = temp(i,j)
          ENDDO
         ENDDO
C-      end loop on np
        ENDDO

      ELSE

C--   All proceses except 0 wait to be polled then send local array
#ifndef DISABLE_MPI_READY_TO_RECEIVE
        CALL MPI_RECV (ready_to_receive, 1, MPI_INTEGER,
     &        idest, itag, MPI_COMM_MODEL, istatus, ierr)
#endif
        CALL MPI_SEND (procBuff, lbuff, _MPI_TYPE_R8,
     &        idest, itag, MPI_COMM_MODEL, ierr)

      ENDIF

#endif /* ALLOW_USE_MPI */

      _END_MASTER( myThid )

      RETURN
      END

