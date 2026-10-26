/* Old iSH lacks setfsuid32/setfsgid32 used by ncurses' safe file helpers.
 * For an unprivileged (real == effective IDs) process, no ID change is needed.
 * Reject elevated processes rather than silently skipping a privilege drop.
 * Load only through the iSH shell wrapper, never /etc/ld.so.preload.
 */
#ifdef ISH_STANDALONE_BUILD
#if !defined(__i386__)
#error Standalone declarations require Linux i386
#endif
typedef unsigned int mode_t;
typedef struct opaque_file FILE;
extern unsigned int getuid(void), geteuid(void), getgid(void), getegid(void);
extern int open(const char *, int, ...);
extern FILE *fopen(const char *, const char *);
extern int *__errno_location(void);
#define errno (*__errno_location())
#define EACCES 13
#else
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#endif

static int same_ids(void)
{
    if (getuid() == geteuid() && getgid() == getegid())
        return 1;
    errno = EACCES;
    return 0;
}

int _nc_safe_open3(const char *path, int flags, mode_t mode)
{
    return same_ids() ? open(path, flags, mode) : -1;
}

FILE *_nc_safe_fopen(const char *path, const char *mode)
{
    return same_ids() ? fopen(path, mode) : (FILE *)0;
}
