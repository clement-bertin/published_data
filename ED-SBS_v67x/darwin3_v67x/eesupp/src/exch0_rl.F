#include "CPP_EEOPTIONS.h"

C--  File exch0_rx.template: to replace EXCH routines when using disconnected tiles
C--   Contents
C--   o EXCH0_RL
C--   o FILL_HALO_LOCAL_RL

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

CBOP

C     !ROUTINE: EXCH0_RL

C     !INTERFACE:
      SUBROUTINE EXCH0_RL(
     U                 array,
     I                 myOLw, myOLe, myOLs, myOLn, myNr,
     I                 exchWidthX, exchWidthY,
     I                 cornerMode, myThid )

C     !DESCRIPTION:
C     *==========================================================*
C     | SUBROUTINE EXCH0_RL
C     | o Replace Exchange routines for the special case
C     |   where tiles are disconnected (no exchange between tiles,
C     |   just fill in edges of an array assuming locally periodic
C     |   subdomain)
C     *==========================================================*
C     |  RL arrays are used to generate code for all 4 types
C     |  of arrays (R4, R8, RS and RL)
C     *==========================================================*

C     !USES:
      IMPLICIT NONE

C     == Global data ==
#include "SIZE.h"
#include "EEPARAMS.h"

C     !INPUT/OUTPUT PARAMETERS:
C     == Routine arguments ==
C     array       :: Array with edges to exchange.
C     myOLw,myOLe :: West  and East  overlap region sizes.
C     myOLs,myOLn :: South and North overlap region sizes.
C     myNr        :: array 3rd dimension
C     exchWidthX  :: Width of data region exchanged in X.
C     exchWidthY  :: Width of data region exchanged in Y.
C     cornerMode  :: Flag indicating whether corner updates are needed.
C     myThid      :: my Thread Id number

      INTEGER myOLw, myOLe, myOLs, myOLn, myNr
      _RL     array( 1-myOLw:sNx+myOLe, 1-myOLs:sNy+myOLn,
     &               myNr, nSx, nSy )
      INTEGER exchWidthX
      INTEGER exchWidthY
      INTEGER cornerMode
      INTEGER myThid

#ifdef DISCONNECTED_TILES
C     !LOCAL VARIABLES:
C     == Local variables ==
C     bi, bj      :: tile indices
      INTEGER bi, bj
CEOP

C--   Error checks
      IF ( exchWidthX .GT. myOLw   )
     &  STOP ' S/R EXCH0_RL: exchWidthX .GT. myOLw'
      IF ( exchWidthX .GT. myOLe   )
     &  STOP ' S/R EXCH0_RL: exchWidthX .GT. myOLe'
      IF ( exchWidthY .GT. myOLs   )
     &  STOP ' S/R EXCH0_RL: exchWidthY .GT. myOLs'
      IF ( exchWidthY .GT. myOLn   )
     &  STOP ' S/R EXCH0_RL: exchWidthY .GT. myOLn'
      IF (       cornerMode .NE. EXCH_IGNORE_CORNERS
     &     .AND. cornerMode .NE. EXCH_UPDATE_CORNERS )
     &  STOP ' S/R EXCH0_RL: Unrecognised cornerMode '

C--   Over all tiles
      DO bj = myByLo(myThid), myByHi(myThid)
       DO bi = myBxLo(myThid), myBxHi(myThid)
         CALL FILL_HALO_LOCAL_RL(
     U                  array(1-myOLw,1-myOLs,1,bi,bj),
     I                  myOLw, myOLe, myOLs, myOLn, myNr,
     I                  cornerMode, bi, bj, myThid )
       ENDDO
      ENDDO

#else /* DISCONNECTED_TILES */
      STOP 'ABNORMAL END: S/R EXCH0_RL is empty'
#endif /* DISCONNECTED_TILES */

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C     !ROUTINE: FILL_HALO_LOCAL_RL

C     !INTERFACE:
      SUBROUTINE FILL_HALO_LOCAL_RL(
     U                 locFld,
     I                 myOLw, myOLe, myOLs, myOLn, myNr,
c    I                 exchWidthX, exchWidthY,
     I                 cornerMode, bi, bj, myThid )

C     !DESCRIPTION:
C     *==========================================================*
C     | SUBROUTINE FILL_HALO_LOCAL_RL
C     | o Fill the halo region of a tile-local array assuming
C     |   disconnected tiles with locally periodic subdomain
C     *==========================================================*

C     !USES:
      IMPLICIT NONE

C     == Global variables ==
#include "SIZE.h"
#include "EEPARAMS.h"

C     !INPUT/OUTPUT PARAMETERS:
C     == Routine arguments ==
C     locFld      :: field local-array with edges to fill.
C     myOLw,myOLe :: West  and East  overlap region sizes.
C     myOLs,myOLn :: South and North overlap region sizes.
C     myNr        :: field local-array 3rd dimension
C     exchWidthX  :: Width of data region exchanged in X.
C     exchWidthY  :: Width of data region exchanged in Y.
C     cornerMode  :: Flag indicating whether corner updates are needed.
C     myThid      :: my Thread Id number
C     bi, bj      :: tile indices
C     myThid      :: thread number
      INTEGER myOLw, myOLe, myOLs, myOLn, myNr
      _RL     locFld( 1-myOLw:sNx+myOLe, 1-myOLs:sNy+myOLn, myNr )
c     INTEGER exchWidthX, exchWidthY
      INTEGER cornerMode
      INTEGER bi, bj
      INTEGER myThid

#ifdef DISCONNECTED_TILES
C     !LOCAL VARIABLES:
C     == Local variables ==
C      i,j,k      :: loop indices
      INTEGER i,j,k
      INTEGER iMin,iMax,jMin,jMax
CEOP

      IF ( cornerMode .EQ. EXCH_UPDATE_CORNERS ) THEN
        iMin =  1  - myOLw
        iMax = sNx + myOLe
        jMin =  1  - myOLs
        jMax = sNy + myOLn
      ELSE
        iMin =  1
        iMax = sNx
        jMin =  1
        jMax = sNy
      ENDIF

C--   Fill Edges in X direction :
      IF ( sNx.EQ.1 ) THEN
C-     Special case for Y-slice domain i.e. case where sNx=1 (faster than below)
         DO k = 1,myNr
           DO j = jMin,jMax
             DO i = 1-myOLw,sNx+myOLe
              locFld(i,j,k) = locFld(1,j,k)
             ENDDO
           ENDDO
         ENDDO
      ELSEIF ( sNx.LT.myOLw ) THEN
C-     Special case if sNx<myOLw, e.g., for Y-slice domain case where sNx = 1
         DO k = 1,myNr
           DO j = jMin,jMax
C      reverse loop index increment to stay valid even if sNx<myOLw;
C      note: cannot vectorize both i loops
             DO i = 0,1-myOLw,-1
              locFld(i,j,k) = locFld(i+sNx,j,k)
             ENDDO
             DO i = 1,myOLe
              locFld(i+sNx,j,k) = locFld(i,j,k)
             ENDDO
           ENDDO
         ENDDO
      ELSE
         DO k = 1,myNr
           DO j = jMin,jMax
             DO i = 1-myOLw,0
              locFld(i,j,k) = locFld(i+sNx,j,k)
             ENDDO
             DO i = 1,myOLe
              locFld(i+sNx,j,k) = locFld(i,j,k)
             ENDDO
           ENDDO
         ENDDO
      ENDIF

C--   Fill Edges in Y direction :
      IF ( sNy.EQ.1 ) THEN
C-     Special case for X-slice domain i.e. case where sNy=1 (faster than below)
         DO k = 1,myNr
           DO j = 1-myOLs,sNy+myOLn
             DO i = iMin,iMax
              locFld(i,j,k) = locFld(i,1,k)
             ENDDO
           ENDDO
         ENDDO
      ELSEIF ( sNy.LT.myOLs ) THEN
C-     Special case if sNy<myOLs, e.g., for X-slice domain case where sNy = 1
         DO k = 1,myNr
C      reverse loop index increment to stay valid even if sNy<myOLs;
C      note: cannot vectorize both j loops
           DO j = 0,1-myOLs,-1
             DO i = iMin,iMax
              locFld(i,j,k) = locFld(i,j+sNy,k)
             ENDDO
           ENDDO
           DO j = 1,myOLn
             DO i = iMin,iMax
              locFld(i,j+sNy,k) = locFld(i,j,k)
             ENDDO
           ENDDO
         ENDDO
      ELSE
         DO k = 1,myNr
           DO j = 1-myOLs,0
             DO i = iMin,iMax
              locFld(i,j,k) = locFld(i,j+sNy,k)
             ENDDO
           ENDDO
           DO j = 1,myOLn
             DO i = iMin,iMax
              locFld(i,j+sNy,k) = locFld(i,j,k)
             ENDDO
           ENDDO
         ENDDO
      ENDIF

#else /* DISCONNECTED_TILES */
      STOP 'ABNORMAL END: S/R FILL_HALO_LOCAL_RL is empty'
#endif /* DISCONNECTED_TILES */

      RETURN
      END
