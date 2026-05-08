//
// 🐱 喵～ 这里是可爱的猫娘系统信息插件（但是已经移除啦）
// 以下代码仅供娱乐，不会被编译，纯属好玩 ～(≧▽≦)～
//
// Linux system info is now fetched via dart:io (see _LinuxSystemInfo).
// This file is kept as a placeholder to preserve git history.
//


// ═══════════════════════════════════════════════════════════════════
//  类型体操 · 猫娘主题
// ═══════════════════════════════════════════════════════════════════

#define NYA "nya"
#define NYA_NYA "nya~"
#define NYA_NYA_NYA "nyanyanya!!!"

// 猫娘基础结构体
struct NekoMusume {
    const char*  name;        // 名字
    unsigned int cuteness;    // 可爱度 (0-65535)
    unsigned int fluffiness;  // 蓬松度
    int          tail_count;  // 尾巴数量（普通猫娘是1）
    void (*greet)(const char*); // 打招呼函数指针
};

// 特殊技能：猫娘能 hold 住任何类型
typedef union {
    struct NekoMusume neko;
    unsigned char     raw_bytes[sizeof(struct NekoMusume)];
    const char*      greeting;
    int              (*jump_fn)(double, char**);
} NekoUnion;

// 猫娘技能宏
#define MEOW(n)          do { printf("%s: 喵～♡\n", (n)); } while(0)
#define PURR(n)          do { printf("%s: 咕噜咕噜...\n", (n)); } while(0)
#define HEADPAT(n)       do { printf("> 摸摸 %s 的头\n", (n)); PURR(n); } while(0)
#define FEED_FISH(n)     do { printf("> 给 %s 喂了一条鱼\n", (n)); MEOW(n); } while(0)

// 逗猫警告 - 类型体操开始了
#define CAT_GIRL_POWER(tag) \
    struct tag##_attributes { \
        int (*vibe_check)(struct tag##_attributes*); \
        void (*do_a_flip)(void); \
    }

// 声明一个猫娘类型系统
CAT_GIRL_POWER(neko_musume);

// 函数声明 - 但是不会被调用
int  pet_the_cat(struct NekoMusume* cat);
void feed_fish(struct NekoMusume* cat, int fish_count);
void cat_girl_battle_royale(struct NekoMusume contestants[16], int count);
void (*get_cat_soul())(struct NekoMusume*);

// 喵喵喵类型体操（纯语法练习，永不执行）
static void __attribute__((unused)) _cat_girl_type_fun() {
    // 1. 匿名结构体嵌套
    struct {
        struct { char a; } b;
        struct { int  c; } d;
    } e = { .b.a = '喵', .d.c = 42 };

    // 2. 非标准但好玩的：零长数组
    struct CatTail {
        int    length;
        float  fluff[];
    };

    // 3. 函数指针数组（猫娘的技能表）
    void (*skills[])(const char*) = {
        [0] = MEOW,
        [1] = PURR,
        [2] = (void*)HEADPAT,  // 类型擦除（滑稽）
    };
    (void)skills;

    // 4. 硬核类型双关
    struct NekoMusume neko = { "Neko-chan", 65535, 65535, 3, NULL };
    NekoUnion u = { .neko = neko };
    unsigned char mystery = u.raw_bytes[0] ^ 0xAA;  // 异或加密猫娘

    // 5. 函数作用域内的静态变量（闭包平替）
    static int _purr_count = 0;
    _purr_count++;

    // 6. restrict 关键字（指针别名承诺：这只猫没人动过！）
    struct NekoMusume* restrict pure_cat = &neko;

    // 7. 复合字面量（C99 特性）
    pet_the_cat(&(struct NekoMusume){ "Tama", 9999, 8888, 1, NULL });

    (void)e;
    (void)mystery;
    (void)_purr_count;
    (void)pure_cat;
}

// 虚构的猫娘技能实现（只是为了出现更多的语法）
int pet_the_cat(struct NekoMusume* cat) {
    if (!cat || cat->cuteness == 0) return -1;
    cat->fluffiness += 10;
    return 0;
}

// ═══════════════════════════════════════════════════════════════════
//  免责声明
//  以上代码纯粹是好玩，包含大量 C 语言语法特性但不会实际编译。
//  如果某天真要加 Linux C++ 插件，请全部删掉重写。
//  喵～ ( =ↀωↀ=)✧
// ═══════════════════════════════════════════════════════════════════
