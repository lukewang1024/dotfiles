/* Scoped APK workaround for iSH builds without Linux fchmodat2 (syscall 452).
 * Build: cc -shared -fPIC -O2 apk-compat.c -o libapk-compat.so
 * Preload only for APK, never as a system-wide library.
 */
#ifdef ISH_STANDALONE_BUILD
#if !defined(__i386__)
#error The standalone ABI declarations are for Linux i386 only
#endif
typedef unsigned int mode_t;
extern int openat(int, const char *, int, ...);
extern int fchmod(int, mode_t);
extern int close(int);
extern int *__errno_location(void);
#define errno (*__errno_location())
#define AT_SYMLINK_NOFOLLOW 0x100
#define O_RDONLY 0
#define O_NONBLOCK 0x800
#define O_NOFOLLOW 0x20000
#define O_CLOEXEC 0x80000
#define EINVAL 22
#else
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>
#endif

/* APK changes permissions of extracted regular files and directories. Opening
 * with O_NOFOLLOW keeps its final-component symlink protection intact. Apply
 * permissions to the opened inode, rather than checking then following a path.
 */
int fchmodat(int dirfd, const char *path, mode_t mode, int flags)
{
    if (flags & ~AT_SYMLINK_NOFOLLOW) {
        errno = EINVAL;
        return -1;
    }
    int options = O_RDONLY | O_NONBLOCK | O_CLOEXEC;
    if (flags & AT_SYMLINK_NOFOLLOW)
        options |= O_NOFOLLOW;
    int fd = openat(dirfd, path, options);
    if (fd < 0)
        return -1;
    int result = fchmod(fd, mode);
    int saved_errno = errno;
    close(fd);
    errno = saved_errno;
    return result;
}
