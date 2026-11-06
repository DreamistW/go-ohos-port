#include "libgoohos.h"

/* 链接验收同时引用两个真实的 Go 导出符号。 */
int32_t GoOhosLinkProbe(void)
{
    return GoOhosAdd(19, 23) + GoOhosInterfaceCount();
}
