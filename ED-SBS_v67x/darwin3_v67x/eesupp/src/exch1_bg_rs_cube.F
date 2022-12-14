#include "CPP_EEOPTIONS.h"

CBOP

C     !ROUTINE: EXCH1_BG_RS_CUBE

C     !INTERFACE:
      SUBROUTINE EXCH1_BG_RS_CUBE(
     U                 uField, vField,
     I                 withSigns,
     I                 myOLw, myOLe, myOLs, myOLn, myNz,
     I                 exchWidthX, exchWidthY,
     I                 cornerMode, myThid )

C     !DESCRIPTION:
C     *==========================================================*
C     | SUBROUTINE EXCH1_BG_RS_CUBE
C     | o Forward-mode edge exchanges for RS vector on CS config:
C     |   Fill overlap region through tile exchanges,
C     |   according to CS topology,
C     |   for a 2-Components B-Grid vector field RS arrays.
C     *==========================================================*
C     | Proceeds in 2 steps :
C     |  1) fill the edges to get valid fields over (1:sNx+1,1:sNy+1)
C     |  2) fill in overlap region:
C     |     (1-Olx:0 & sNx+2:sNx+Olx) x (1-Oly:0 & sNy+2:sNy+Oly)
C     | Only works: a) with exactly 6 tiles (1 per face)
C     |             b) no MPI
C     |             c) thread shared arrays (in common block)
C     *==========================================================*

C     !USES:
      IMPLICIT NONE

C     == Global data ==
#include "SIZE.h"
#include "EEPARAMS.h"

C     !INPUT/OUTPUT PARAMETERS:
C     == Routine arguments ==
C     uField     :: 1rst component array with overlap to exchange.
C     vField     :: 2nd  component array with overlap to exchange.
C     withSigns  :: sign of uField,vField depends on orientation.
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
      _RS uField( 1-myOLw:sNx+myOLe, 1-myOLs:sNy+myOLn,
     &            myNz, nSx, nSy )
      _RS vField( 1-myOLw:sNx+myOLe, 1-myOLs:sNy+myOLn,
     &            myNz, nSx, nSy )
      LOGICAL withSigns
      INTEGER exchWidthX
      INTEGER exchWidthY
      INTEGER cornerMode
      INTEGER myThid

C     !LOCAL VARIABLES:
C     == Local variables ==
C     theSimulationMode :: Holds working copy of simulation mode
C     theCornerMode     :: Holds working copy of corner mode
C     i,j,k,repeat      :: Loop counters and index
C     bt,bn,bs,be,bw
c     INTEGER theSimulationMode
c     INTEGER theCornerMode
      INTEGER i,j,k
      INTEGER updateEdges, j1, j2, j3
      INTEGER bt,bn,bs,be,bw
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      _RS negOne

C     == Statement function ==
      INTEGER tilemod
      tilemod(i)=1+mod(i-1+6,6)
CEOP

c     theSimulationMode = FORWARD_SIMULATION
c     theCornerMode     = cornerMode

c     IF ( simulationMode.EQ.REVERSE_SIMULATION ) THEN
c       WRITE(msgBuf,'(A)')'EXCH1_BG_RS_CUBE: AD mode not implemented'
c       CALL PRINT_ERROR( msgBuf, myThid )
c       STOP 'ABNORMAL END: EXCH1_BG_RS_CUBE: no AD code'
c     ENDIF
      IF ( sNx.NE.sNy .OR.
     &     nSx.NE.6 .OR. nSy.NE.1 .OR.
     &     nPx.NE.1 .OR. nPy.NE.1 ) THEN
        WRITE(msgBuf,'(2A)') 'EXCH1_BG_RS_CUBE: Wrong Tiling'
        CALL PRINT_ERROR( msgBuf, myThid )
        WRITE(msgBuf,'(2A)') 'EXCH1_BG_RS_CUBE: ',
     &   'works only with sNx=sNy & nSx=6 & nSy=nPx=nPy=1'
        CALL PRINT_ERROR( msgBuf, myThid )
        STOP 'ABNORMAL END: EXCH1_BG_RS_CUBE: Wrong Tiling'
      ENDIF

C-- Could by-pass 1rst step (with updateEdges= 0) if vector field is
C   valid over (1:sNx+1,1:sNy+1); In general this should be the case
C   for correct computation domain; but some exceptions ? + I/O problems
C-- Exch of 2-Components vector (assumed to be 90.deg apart) at corner
C   point is ill defined since we have 3 axes @ 120.deg apart.
C   go with 3 options :
C      updateEdges = 1 : do not touch corner values ;
C      updateEdges = 2 : copy from corresponding face S.W corner (<= clear owner)
C                        and do nothing for missing corners ;
C      updateEdges = 3 : copy all corner values.
C------
      updateEdges = 2
      IF ( withSigns ) updateEdges = MIN(1,updateEdges)

      negOne = 1.
      IF (withSigns) negOne = -1.

C     For now tile<->tile exchanges are sequentialised through
C     thread 1. This is a temporary feature for preliminary testing until
C     general tile decomposistion is in place (CNH April 11, 2001)
      CALL BAR2( myThid )
      _BEGIN_MASTER( myThid )

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

      IF ( updateEdges.GT.0 ) THEN
C-- 1rst Step : Just fill-in North (j=sNy+1) & East (i=sNx+1) edges

       j1 = 2
       j2 = 2
       j3 = sNy
       IF ( updateEdges.GE.2 ) THEN
         j1 = 1
         j3 = sNy+1
       ENDIF
       IF ( updateEdges.EQ.3 ) j2 = 1

       DO bt = 1,nSx
        IF ( MOD(bt,2).EQ.1 ) THEN
C      Odd face Number:

         bn=tilemod(bt+2)
         bs=tilemod(bt-1)
         be=tilemod(bt+1)
         bw=tilemod(bt-2)

         i = 1
         DO k = 1, myNz
C         Tile Odd:Odd+2 [get] [North<-West]
          DO j = j2, j3
           uField(j,sNy+i,k,bt,1) = vField(i,sNy+2-j,k,bn,1)*negOne
           vField(j,sNy+i,k,bt,1) = uField(i,sNy+2-j,k,bn,1)
          ENDDO
C         Tile Odd:Odd+1 [get] [East<-West]
          DO j = j1, sNy
           uField(sNx+i,j,k,bt,1) = uField(i,j,k,be,1)
           vField(sNx+i,j,k,bt,1) = vField(i,j,k,be,1)
          ENDDO
         ENDDO

        ELSE
C      Even face Number:

         bn=tilemod(bt+1)
         bs=tilemod(bt-2)
         be=tilemod(bt+2)
         bw=tilemod(bt-1)

         i = 1
         DO k = 1, myNz
C         Tile Even:Even+1 [get] [North<-South]
          DO j = j1, sNy
           uField(j,sNy+i,k,bt,1) = uField(j,i,k,bn,1)
           vField(j,sNy+i,k,bt,1) = vField(j,i,k,bn,1)
          ENDDO
C         Tile Even:Even+2 [get] [East<-South]
          DO j = j2, j3
           uField(sNx+i,j,k,bt,1) = vField(sNx+2-j,i,k,be,1)
           vField(sNx+i,j,k,bt,1) = uField(sNx+2-j,i,k,be,1)*negOne
          ENDDO
         ENDDO

C--    end odd/even face number
        ENDIF
C--    end loop on tile index bt
       ENDDO

C-- End of 1rst Step
      ENDIF

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

C-- 2nd Step: fill-in (true) overlap regions:

      DO bt = 1,nSx
       IF ( MOD(bt,2).EQ.1 ) THEN
C      Odd face Number:

         bn=tilemod(bt+2)
         bs=tilemod(bt-1)
         be=tilemod(bt+1)
         bw=tilemod(bt-2)

         DO k = 1, myNz
          DO j = 1, sNy+1
           DO i = 2, exchWidthX

C          Tile Odd:Odd+2 [get] [North<-West]
           uField(j,sNy+i,k,bt,1) = vField(i,sNy+2-j,k,bn,1)*negOne
           vField(j,sNy+i,k,bt,1) = uField(i,sNy+2-j,k,bn,1)
C          Tile Odd:Odd+1 [get] [East<-West]
           uField(sNx+i,j,k,bt,1) = uField(i,j,k,be,1)
           vField(sNx+i,j,k,bt,1) = vField(i,j,k,be,1)

          ENDDO
          DO i = 1-exchWidthX, 0

C          Tile Odd:Odd-1 [get] [South<-North]
           uField(j,i,k,bt,1) = uField(j,sNy+i,k,bs,1)
           vField(j,i,k,bt,1) = vField(j,sNy+i,k,bs,1)
C          Tile Odd:Odd-2 [get] [West<-North]
           uField(i,j,k,bt,1) = vField(sNx+2-j,sNy+i,k,bw,1)
           vField(i,j,k,bt,1) = uField(sNx+2-j,sNy+i,k,bw,1)*negOne

          ENDDO
         ENDDO
        ENDDO

       ELSE
C      Even face Number:

        bn=tilemod(bt+1)
        bs=tilemod(bt-2)
        be=tilemod(bt+2)
        bw=tilemod(bt-1)

        DO k = 1, myNz
         DO j = 1, sNy+1
          DO i = 2, exchWidthX

C          Tile Even:Even+2 [get] [East<-South]
           uField(sNx+i,j,k,bt,1) = vField(sNx+2-j,i,k,be,1)
           vField(sNx+i,j,k,bt,1) = uField(sNx+2-j,i,k,be,1)*negOne
C          Tile Even:Even+1 [get] [North<-South]
           uField(j,sNy+i,k,bt,1) = uField(j,i,k,bn,1)
           vField(j,sNy+i,k,bt,1) = vField(j,i,k,bn,1)

          ENDDO
          DO i = 1-exchWidthX, 0

C          Tile Even:Even-2 [get] [South<-East]
           uField(j,i,k,bt,1) = vField(sNx+i,sNy+2-j,k,bs,1)*negOne
           vField(j,i,k,bt,1) = uField(sNx+i,sNy+2-j,k,bs,1)
C          Tile Even:Even-1 [get] [West<-East]
           uField(i,j,k,bt,1) = uField(sNx+i,j,k,bw,1)
           vField(i,j,k,bt,1) = vField(sNx+i,j,k,bw,1)

          ENDDO
         ENDDO
        ENDDO

C--    end odd/even face number
       ENDIF
C--    end loop on tile index bt
      ENDDO

      _END_MASTER( myThid )
      CALL BAR2(myThid)

      RETURN
      END
