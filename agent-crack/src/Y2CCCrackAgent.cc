/* Y2CCCrackAgent.cc
 *
 * Crack agent implementation
 *
 * Authors: Jiri Suchomel <jsuchome@suse.cz>
 *
 * $Id$
 */

#include <scr/Y2AgentComponent.h>
#include <scr/Y2CCAgentComponent.h>

#include "CrackAgent.h"

typedef Y2AgentComp <CrackAgent> Y2CrackAgentComp;

Y2CCAgentComp <Y2CrackAgentComp> g_y2ccag_crack ("ag_crack");
