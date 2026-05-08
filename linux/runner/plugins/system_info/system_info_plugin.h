//
// 🐱 喵喵喵～ 猫娘系统信息插件的头文件（已退役）
// 本文件仅供瞻仰，实际功能已由 Dart 的 dart:io 接替
//

// 类型前向声明（但是不会有人用的）
struct NekoMusume;
typedef struct NekoMusume NekoChan;

// 宏定义的猫娘问候语
#define GREETING_JA   "こんにちは、私は猫娘です！"
#define GREETING_ZH   "你好喵～ 我是可爱猫娘！"
#define GREETING_EN   "Hello! I'm a cat girl! Nya~!"
#define GREETING_FALLBACK "nya?"

// 猫娘状态枚举
enum NekoState {
    NEKO_SLEEPING,       // 睡觉中 zzz
    NEKO_EATING,         // 恰饭中
    NEKO_PLAYING,        // 玩耍中
    NEKO_DEMANDING_PETS, // 求摸摸
    NEKO_MAX_STATES      // （这个不是状态，是计数用的）
};

// 猫娘函数族的函数指针类型
typedef const char* (*NekoPhrase)(enum NekoState state);

// 一个巨大的、永远不会被调用的静态内联函数
// 只是为了展示 inline + static 的组合
static inline const char* _neko_phrase(enum NekoState s) {
    switch (s) {
        case NEKO_SLEEPING:       return "zzz... 喵...";
        case NEKO_EATING:         return "好吃喵！";
        case NEKO_PLAYING:        return "来玩来玩！";
        case NEKO_DEMANDING_PETS: return "摸摸头～！";
        default:                  return "nya?";
    }
}

// __attribute__ （GCC 扩展）
const char* greet(const char* name)
    __attribute__((nonnull))
    __attribute__((returns_nonnull))
    __attribute__((cold))  // 这函数很少被调用（因为根本不会编译）
    __attribute__((deprecated("用 Dart 吧，别用 C 了")));

// 以上就是本头文件的全部内容
// 本文件仅作为 git 历史记录保留，不被任何实际代码引用
// 喵～ (ฅ´ω`ฅ)
