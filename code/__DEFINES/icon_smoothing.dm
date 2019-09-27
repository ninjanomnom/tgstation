//Redefinitions of the diagonal directions so they can be stored in one var without conflicts
#define N_NORTH		(1<<1)
#define N_SOUTH		(1<<2)
#define N_EAST		(1<<4)
#define N_WEST		(1<<8)
#define N_NORTHEAST	(1<<5)
#define N_NORTHWEST	(1<<9)
#define N_SOUTHEAST	(1<<6)
#define N_SOUTHWEST	(1<<10)

#define SMOOTH_FALSE	0				//not smooth
#define SMOOTH_TRUE		(1<<0)	//smooths with exact specified types or just itself
#define SMOOTH_MORE		(1<<1)	//smooths with all subtypes of specified types or just itself (this value can replace SMOOTH_TRUE)
#define SMOOTH_DIAGONAL	(1<<2)	//if atom should smooth diagonally, this should be present in 'smooth' var
#define SMOOTH_BORDER	(1<<3)	//atom will smooth with the borders of the map
#define SMOOTH_QUEUED	(1<<4)	//atom is currently queued to smooth.

#define NULLTURF_BORDER 123456789

#define DEFAULT_UNDERLAY_ICON 			'icons/turf/floors.dmi'
#define DEFAULT_UNDERLAY_ICON_STATE 	"plating"
