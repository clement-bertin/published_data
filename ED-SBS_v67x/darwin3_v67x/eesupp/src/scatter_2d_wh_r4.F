#include "PACKAGES_CONFIG.h"
#include "CPP_EEOPTIONS.h"

CBOP
C !ROUTINE: SCATTER_2D_WH_R4
C !INTERFACE:
      SUBROUTINE SCATTER_2D_WH_R4(
     I                  gloBuff,
     O                  procBuff,
     I                  myThid )
C !DESCRIPTION:
C     Scatter elements, including halos, of a global 2-D array from mpi process 0 to all processes.
C     Note: done by Master-Thread ; might need barrier calls before and after
C           this S/R call.

C     !USES:
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "EESUPPORT.h"

C     !INPUT/OUTPUT PARAMETERS:
C gloBuff   ( _R4 ) :: full-domain 2D IO-buffer array             (Input)
C procBuff  ( _R4 ) :: proc-domain 2D IO-buffer array             (Input)
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

      _R4     gloBuff(sNxWh,gloNyWh)
      _R4     procBuff(sNxWh,procNyWh)
      INTEGER myThid
CEOP

C !LOCAL VARIABLES:
      INTEGER i,j
#ifdef ALLOW_USE_MPI
      INTEGER jj, np0, np
      _R4     temp(sNxWh,gloNyWh)
      INTEGER istatus(MPI_STATUS_SIZE), ierr
      INTEGER lbuff, isource, itag
#endif /* ALLOW_USE_MPI */

      _BEGIN_MASTER( myThid )

#ifdef ALLOW_USE_MPI

      lbuff = sNxWh*procNyWh
      isource = 0
      itag  = 0

      IF( mpiMyId .EQ. 0 ) THEN

C--   Process 0 sends local arrays to all other processes
        DO np = 2, numberOfProcs
         np0 = np - 1

C--   Process 0 extract the local arrays from the global buffer.
         DO j=1,procNyWh
          DO i=1,sNxWh
           jj=j+procNyWh*(np-1)
           temp(i,j) = gloBuff(i,jj)
          ENDDO
         ENDDO

C--   Process 0 sends local arrays to all other processes
         CALL MPI_SEND (temp, lbuff, _MPI_TYPE_R4,
     &           np0, itag, MPI_COMM_MODEL, ierr)

C-      end loop on np
        ENDDO

      ELSE

C--   All proceses except 0 receive local array from process 0
         CALL MPI_RECV (procBuff, lbuff, _MPI_TYPE_R4,
     &        isource, itag, MPI_COMM_MODEL, istatus, ierr)

      ENDIF

#endif /* ALLOW_USE_MPI */

      IF( myProcId .EQ. 0 ) THEN
C--   Process 0 fills-in its local data

        DO j=1,procNyWh
         DO i=1,sNxWh
          procBuff(i,j) = gloBuff(i,j)
         ENDDO
        ENDDO

c        DO j=1,gloNyWh
c          DO i=1,sNxWh
c            gloBuff(i,j) = 0.
c          ENDDO
c        ENDDO

C-    end if myProcId = 0
      ENDIF

      _END_MASTER( myThid )

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
