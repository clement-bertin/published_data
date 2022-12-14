#include "CPP_EEOPTIONS.h"

CBOP
C !ROUTINE: SCATTER_VEC_R8
C !INTERFACE:
      SUBROUTINE SCATTER_VEC_R8(
     I                  gloBuff,
     O                  myField,
     I                  length,
     I                  myThid )
C !DESCRIPTION:
C     Scatter elements of a global 1-D array from mpi process 0 to all processes.
C     Note: done by Master-Thread ; might need barrier calls before and after
C           this S/R call.

C     !USES:
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "EESUPPORT.h"

C     !INPUT/OUTPUT PARAMETERS:
C gloBuff   ( _R8 ) :: full-domain IO-buffer array      (Input)
C myField   ( _R8 ) :: local (i.e. my Proc.) 1D array  (Output)
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
      INTEGER lbuff, isource, itag
#endif /* ALLOW_USE_MPI */

      _BEGIN_MASTER( myThid )

#ifdef ALLOW_USE_MPI
      IF ( usingMPI ) THEN

       lbuff = length
       isource = 0
       itag  = 0

       IF ( mpiMyId .EQ. 0 ) THEN

C--   Process 0 sends pieces of global array to all other processes
        DO np = 2, nPx*nPy

          pId = np - 1
          jG = 1 + ( np - 1 )*length
          CALL MPI_SEND ( gloBuff(jG), lbuff, _MPI_TYPE_R8,
     &                    pId, itag, MPI_COMM_MODEL, ierr )

C-      end loop on np
        ENDDO

       ELSE

C--   All proceses except 0 receive local array from process 0
         CALL MPI_RECV ( myField, lbuff, _MPI_TYPE_R8,
     &        isource, itag, MPI_COMM_MODEL, istatus, ierr )

       ENDIF

      ENDIF
#endif /* ALLOW_USE_MPI */

      IF ( myProcId .EQ. 0 ) THEN
C--   Process 0 fills-in its local data

        DO j=1,length
          myField(j) = gloBuff(j)
        ENDDO

C-    end if myProcId = 0
      ENDIF

      _END_MASTER( myThid )

      RETURN
      END
