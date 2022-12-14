#include "GCHEM_OPTIONS.h"
#ifdef ALLOW_DARWIN
#include "DARWIN_OPTIONS.h"
#endif

C !INTERFACE: ==========================================================
      SUBROUTINE GCHEM_OUTPUT( myTime, myIter, myThid )

C !DESCRIPTION:
C calls subroutine that calculate diagnostic specific to
C any tracer epxperiment
C also calls gchem monitor

C !USES: ===============================================================
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GCHEM.h"

C !INPUT PARAMETERS: ===================================================
C  myThid   :: my Thread Id number
      _RL     myTime
      INTEGER myIter
      INTEGER myThid
CEOP

#ifdef ALLOW_GCHEM
cccccccccccccccccccccc
c diagnostics        c
cccccccccccccccccccccc

#ifdef ALLOW_DIC
#ifdef ALLOW_TIMEAVE
       IF ( myIter.NE.nIter0 )
     & CALL DIC_BIOTIC_DIAGS( myTime, myIter, myThid )
#endif /* ALLOW_TIMEAVE */
#endif /* ALLOW_DIC */

#ifdef ALLOW_DARWIN
#ifdef ALLOW_TIMEAVE
      IF ( useDARWIN ) THEN
       CALL DARWIN_DIAGS( myTime, myIter, myThid )
      ENDIF
#endif
#endif


#endif /* ALLOW_GCHEM */

      RETURN
      END
