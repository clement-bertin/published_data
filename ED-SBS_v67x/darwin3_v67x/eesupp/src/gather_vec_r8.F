#include "CPP_EEOPTIONS.h"

CBOP
C !ROUTINE: GATHER_VEC_R8
C !INTERFACE:
      SUBROUTINE GATHER_VEC_R8(
     O                  gloBuff,
     I                  myField,
     I                  length,
     I                  myThid )
C !DESCRIPTION:
C     Gather elements of a global 1-D array from mpi process 0 to all processes.
C     Note: done by Master-Thread ; might need barrier calls before and after
C           this S/R call.

C     !USES:
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "EESUPPORT.h"

C     !INPUT/OUTPUT PARAMETERS:
C gloBuff   ( _R8 ) :: full-domain IO-buffer array     (Output)
C myField   ( _R8 ) :: local (i.e. my Proc.) 1D array   (Input)
C length   (integer):: size of local 1D array
C myThid   (integer):: my Thread Id number

      INTEGER length
      _R8     gloBuff(length*nPx*nPy)
      _R8     myField(length)
      INTEGER myThid
CEOP

C !LOCAL VARIABLES:
      INTEGER j
#ifdef ALLOW_USE_MPI
      INTEGER jG
      INTEGER np, pId
      INTEGER istatus(MPI_STATUS_SIZE), ierr
      INTEGER lbuff, idest, itag, ready_to_receive
#endif /* ALLOW_USE_MPI */

      _BEGIN_MASTER( myThid )

      IF ( myProcId .EQ. 0 ) THEN
C--   Process 0 fills-in its local data

        DO j=1,length
          gloBuff(j) = myField(j)
        ENDDO

C-    end if myProcId = 0
      ENDIF

#ifdef ALLOW_USE_MPI
      IF ( usingMPI ) THEN

       lbuff = length
       idest = 0
       itag  = 0
       ready_to_receive = 0

       IF ( mpiMyId .EQ. 0 ) THEN

        DO np = 2, nPx*nPy

C--   Process 0 polls and receives data from each process in turn
          pId = np - 1
          jG = 1 + ( np - 1 )*length
#ifndef DISABLE_MPI_READY_TO_RECEIVE
          CALL MPI_SEND ( ready_to_receive, 1, MPI_INTEGER,
     &             pId, itag, MPI_COMM_MODEL, ierr)
#endif
          CALL MPI_RECV ( gloBuff(jG), lbuff, _MPI_TYPE_R8,
     &             pId, itag, MPI_COMM_MODEL, istatus, ierr )

C-      end loop on np
        ENDDO

       ELSE

C--   All proceses except 0 wait to be polled then send local array
#ifndef DISABLE_MPI_READY_TO_RECEIVE
         CALL MPI_RECV ( ready_to_receive, 1, MPI_INTEGER,
     &            idest, itag, MPI_COMM_MODEL, istatus, ierr )
#endif
         CALL MPI_SEND ( myField, lbuff, _MPI_TYPE_R8,
     &            idest, itag, MPI_COMM_MODEL, ierr )

       ENDIF

      ENDIF
#endif /* ALLOW_USE_MPI */

      _END_MASTER( myThid )

      RETURN
      END
