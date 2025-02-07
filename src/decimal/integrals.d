module decimal.integrals;

private import core.bitop : bsr, bsf;
private import std.traits: isUnsigned, isSigned, isSomeChar, Unqual, CommonType, Unsigned, Signed;
private import core.checkedint: addu, subu, mulu, adds, subs;

package:


/* ****************************************************************************************************************** */
/* n BIT UNSIGNED IMPLEMENTATION                                                                                    */
/* ****************************************************************************************************************** */


template MakeUnsigned(int bits)
{
    static if (bits == 8)
        alias MakeUnsigned = ubyte;
    else static if (bits == 16)
        alias MakeUnsigned = ushort;
    else static if (bits == 32)
        alias MakeUnsigned = uint;
    else static if (bits == 64)
        alias MakeUnsigned = ulong;
    else static if (bits >= 128)
        alias MakeUnsigned = unsigned!bits;
    else 
        static assert(0);
}



template isCustomUnsigned(T)
{
    enum isCustomUnsigned = is(T: unsigned!bits, int bits);
}

template isAnyUnsigned(T)
{
    enum isAnyUnsigned = isUnsigned!T || isCustomUnsigned!T;
}

template isUnsignedAssignable(T, U)
{
    enum isUnsignedAssignable = isAnyUnsigned!T && isAnyUnsigned!U && T.sizeof >= U.sizeof;
}

struct unsigned(int bits) if (bits >= 128 && (bits & (bits - 1)) == 0)
{
    alias HALF = MakeUnsigned!(bits / 2);

    alias THIS = typeof(this);

    version (LittleEndian) { HALF lo; HALF hi; } else { HALF hi; HALF lo; }

    enum min  = THIS();
    enum max = THIS(HALF.max, HALF.max);
    

    this(T, U)(auto const ref T hi, auto const ref U lo)
    if (isUnsignedAssignable!(HALF, T) && isUnsignedAssignable!(HALF, U))
    {
        this.hi = hi;
        this.lo = lo;
    }

    this(T)(auto const ref T x) 
    if (isUnsignedAssignable!(HALF, T))
    {
        this.lo = x;
    }

    this(string s)
    {
        assert (s.length, "Empty string");
        size_t i = 0;
        if (s.length > 2 && s[0] == '0' && (s[1] == 'x' || s[1] == 'X'))
        {
            i+=2;
            assert (i < s.length, "Empty hexadecimal string");
            while (i < s.length && (s[i] == '0' || s[i] == '_'))
                ++i;
            int width = 0;
            int maxWidth = THIS.sizeof * 8;
            while (i < s.length)
            {
                assert (width < maxWidth, "Overflow");
                char c = s[i++];
                if (c >= '0' && c <= '9')
                {
                    this <<= 4;
                    lo |= cast(uint)(c - '0');
                    width += 4;
                }
                else if (c >= 'A' && c <= 'F')
                {
                    this <<= 4;
                    lo |= cast(uint)(c - 'A' + 10);
                    width += 4;
                }
                else if (c >= 'a' && c <= 'f')
                {
                    this <<= 4;
                    lo |= cast(uint)(c - 'a' + 10);
                    width += 4;
                }
                else
                    assert(c == '_', "Invalid character in input string");
            }
        }
        else
        {
            while (i < s.length)
            {
                char c = s[i++];
                if (c >= '0' && c <= '9')
                {
                    bool ovf;
                    auto r = fma(this, 10U, cast(uint)(c - '0'), ovf);
                    assert(!ovf, "Overflow");
                    this = r;
                }
                else
                    assert(c == '_', "Invalid character in input string");
            }
        }
    }

    
    auto ref opAssign(T)(auto const ref  T x) 
    if (isUnsignedAssignable!(HALF, T))
    {
        this.lo = x;
        this.hi = 0U;
        return this;
    }

    auto opUnary(string op: "+")() const
    {
        return this;
    }

    auto opUnary(string op: "-")() const
    {
        return ++(~this);
    }


    auto opUnary(string op: "~")() const
    {
        return THIS(~hi, ~lo);
    }

    auto ref opUnary(string op:"++")()
    {
        ++lo;
        if (!lo)
            ++hi;
        return this;
    }

    auto ref opUnary(string op:"--")()
    {
        --lo;
        if (lo == HALF.max)
            --hi;
        return this;
    }

    bool opEquals(T)(const T value) const
    if (isUnsignedAssignable!(HALF, T))
    {
        return hi == 0U && lo == value;
    }

    bool opEquals(T: THIS)(auto const ref T value) const
    {
        return hi == value.hi && lo == value.lo;
    }

    int opCmp(T)(const T value) const 
    if (isUnsignedAssignable!(HALF, T))
    {
        if (hi)
            return 1;
        else if (lo > value)
            return 1;
        else if (lo < value)
            return -1;
        else
            return 0;
    }

    int opCmp(T: THIS)(auto const ref T value) const 
    {
        if (hi > value.hi)
            return 1;
        else if (hi < value.hi)
            return -1;
        else if (lo > value.lo)
            return 1;
        else if (lo < value.lo)
            return -1;
        else
            return 0;
    }

    auto opBinary(string op: "|", T: THIS)(auto const ref T value) const
    {
        return THIS(this.hi | value.hi, this.lo | value.lo);
    }

    auto opBinary(string op: "|", T)(auto const ref T value) const 
    if (isUnsignedAssignable!(HALF, T))
    {
        return THIS(this.hi, this.lo | value);
    }

    auto ref opOpAssign(string op: "|", T: THIS)(auto const ref T value)
    {
        this.hi |= value.hi;
        this.lo |= value.lo;
        return this;
    }

    auto ref opOpAssign(string op: "|", T)(auto const ref T value) 
    if (isUnsignedAssignable!(HALF, T))
    {
        this.lo |= value;
        return this;
    }

    auto opBinary(string op: "&", T: THIS)(auto const ref T value) const
    {
        return THIS(this.hi & value.hi, this.lo & value.lo);
    }

    auto opBinary(string op: "&", T)(auto const ref T value) const 
    if (isUnsignedAssignable!(HALF, T))
    {
        return THIS(0U, this.lo & value);
    }

    auto ref opOpAssign(string op: "&", T: THIS)(auto const ref T value)
    {
        this.hi &= value.hi;
        this.lo &= value.lo;
        return this;
    }

    auto ref opOpAssign(string op: "&", T)(auto const ref T value) 
    if (isUnsignedAssignable!(HALF, T))
    {
        this.hi = 0U;
        this.lo &= value;
        return this;
    }

    auto opBinary(string op: "^", T: THIS)(auto const ref T value) const
    {
        return THIS(this.hi ^ value.hi, this.lo ^ value.lo);
    }

    auto opBinary(string op: "^", T)(auto const ref T value) const 
    if (isUnsignedAssignable!(HALF, T))
    {
        return THIS(this.hi ^ 0UL, this.lo ^ value);
    }

    auto ref opOpAssign(string op: "^", T: THIS)(auto const ref T value)
    {
        this.hi ^= value.hi;
        this.lo ^= value.lo;
        return this;
    }

    auto ref opOpAssign(string op: "^", T)(auto const ref T value) 
    if (isUnsignedAssignable!(HALF, T))
    {
        this.hi ^= 0U;
        this.lo ^= value;
        return this;
    }

    auto opBinary(string op)(const int shift) const 
    if (op == ">>" || op == ">>>")
    in
    {
        assert(shift >= 0 && shift < THIS.sizeof * 8);
    }
    body
    {
        enum int halfBits = HALF.sizeof * 8;
        THIS ret = void;
        
        if (shift == halfBits)
        {
            ret.lo = this.hi;
            ret.hi = 0U;
        }
        else if (shift > halfBits)
        {
            ret.lo = this.hi >>> (shift - halfBits);
            ret.hi = 0U;
        }
        else if (shift != 0)
        {
            ret.lo = (this.hi << (halfBits - shift)) | (this.lo >>> shift);
            ret.hi = this.hi >>> shift;
        }
        else
            ret = this;
        return ret;
    }

    auto ref opOpAssign(string op)(const int shift) 
    if (op == ">>" || op == ">>>")
    in
    {
        assert(shift >= 0 && shift < THIS.sizeof * 8);
    }
    body
    {
        enum int halfBits = HALF.sizeof * 8;
        if (shift == halfBits)
        {
            lo = hi;
            hi = 0U;
        }
        else if (shift > halfBits)
        {
            lo = hi >>> (shift - halfBits);
            hi = 0U;
        }
        else if (shift != 0)
        {
            lo = (hi << (halfBits - shift)) | (lo >>> shift);
            hi >>>= shift;
        }
        return this;
    }

    auto opBinary(string op)(const int shift) const 
    if (op == "<<")
    in
    {
        assert(shift >= 0 && shift < THIS.sizeof * 8);
    }
    body
    {
        THIS ret = void;
        enum int halfBits = HALF.sizeof * 8;

        if (shift == halfBits)
        {
            ret.hi = this.lo;
            ret.lo = 0U;
        }
        else if (shift > halfBits)
        {
            ret.hi = this.lo << (shift - halfBits);
            ret.lo = 0U;
        }
        else if (shift != 0)
        {
            ret.hi = (this.lo >>> (halfBits - shift)) | (this.hi << shift);
            ret.lo = this.lo << shift;
        }
        else
            ret = this;
        return ret;
    }

    auto ref opOpAssign(string op)(const int shift) 
    if (op == "<<")
    in
    {
        assert(shift >= 0 && shift < THIS.sizeof * 8);
    }
    body
    {
        enum int halfBits = HALF.sizeof * 8;
        
        if (shift == halfBits)
        {
            hi = lo;
            lo = 0U;
        }
        else if (shift > halfBits)
        {
            hi = lo << (shift - halfBits);
            lo = 0U;
        }
        else if (shift != 0)
        {
            hi = (lo >>> (halfBits - shift)) | (hi << shift);
            lo <<= shift;
        }
        return this;
    }

    auto opBinary(string op :"+", T)(const T value) const 
    if (isUnsignedAssignable!(HALF, T))
    {
        THIS ret = this;
        ret.hi += xadd(ret.lo, value);
        return ret;
    }

    auto ref opOpAssign(string op :"+", T)(const T value) 
    if (isUnsignedAssignable!(HALF, T))
    {
        hi += xadd(lo, value);
        return this;
    }

    auto opBinary(string op :"+", T: THIS)(const T value) const 
    {
        THIS ret = this;
        ret.hi += xadd(ret.lo, value.lo);
        ret.hi += value.hi;
        return ret;
    }

    auto ref opOpAssign(string op :"+", T: THIS)(auto const ref T value)
    {
        hi += xadd(this.lo, value.lo);
        hi += value.hi;
        return this;
    }

    auto opBinary(string op :"-", T)(const T value) const 
    if (isUnsignedAssignable!(HALF, T))
    {
        THIS ret = this;
        ret.hi -= xsub(ret.lo, value);
        return ret;
    }

    auto ref opOpAssign(string op :"-", T)(const T value) 
    if (isUnsignedAssignable!(HALF, T))
    {
        hi -= xsub(lo, value);
        return this;
    }

    auto opBinary(string op :"-", T: THIS)(const T value) const 
    {
        THIS ret = this;
        ret.hi -= xsub(ret.lo, value.lo);
        ret.hi -= value.hi;
        return ret;
    }

    auto ref opOpAssign(string op :"-", T: THIS)(auto const ref T value)
    {
        this.hi -= xsub(this.lo, value.lo);
        this.hi -= value.hi;
        return this;
    }

    auto opBinary(string op :"*", T)(const T value) const
    if (isUnsignedAssignable!(HALF, T))
    {
        THIS ret = xmul(this.lo, value);
        ret.hi += this.hi * value;
        return ret;
    }

    auto ref opOpAssign(string op :"*", T)(const T value) 
    if (isUnsignedAssignable!(HALF, T))
    {
        THIS ret = xmul(this.lo, value);
        ret.hi += this.hi * value;
        return this = ret;
    }

    auto opBinary(string op :"*", T: THIS)(const T value) const 
    {
        auto ret = xmul(lo, value.lo);       
        ret.hi += this.hi * value.lo + this.lo * value.hi;    
        return ret;
    }

    auto ref opOpAssign(string op :"*", T: THIS)(const T value) 
    {
        auto ret = xmul(lo, value.lo);
        ret.hi += this.hi * value.lo + this.lo * value.hi;
        return this = ret;
    }

    auto opBinary(string op :"/", T)(const T value) const 
    if (isUnsignedAssignable!(HALF, T))
    {
        THIS q = this;
        divrem(q, value);
        return q;
    }

    auto ref opOpAssign(string op :"/", T)(const T value) 
    if (isUnsignedAssignable!(HALF, T))
    {
        divrem(this, value);
    }

    auto opBinary(string op :"/", T: THIS)(const T value) const 
    {
        THIS q = this;
        divrem(q, value);
        return q;
    }

    auto ref opOpAssign(string op :"/", T: THIS)(const T value) 
    {
        divrem(this, value);
    }

    auto opBinary(string op :"%", T)(const T value) const
    if (isUnsignedAssignable!(HALF, T))
    {
        THIS q = this;
        return divrem(q, value);
    }

    auto ref opOpAssign(string op :"%", T)(const T value) 
    if (isUnsignedAssignable!(HALF, T))
    {
        THIS q = this;
        return this = divrem(q, value);       
    }

    auto opBinary(string op :"%", T: THIS)(const T value) const 
    {
        THIS q = this;
        return divrem(q, value);
    }

    auto ref opOpAssign(string op :"%", T: THIS)(const T value) 
    {
        THIS q = this;
        return this = divrem(q, value);   
    }

    auto opCast(T)() const
    {
        static if (is(T: bool))
            return cast(T)(lo | hi);
        else static if (isSomeChar!T)
            return cast(T)lo;
        else static if (isUnsigned!T)
            return cast(T)lo;
        else static if (isUnsignedAssignable!(HALF, T))
            return cast(T)lo;
        else static if (is(T: THIS))
            return this;
        else
            static assert("Cannot cast '" ~ Unqual!THIS.stringof ~ "' to '" ~ Unqual!T.stringof ~ "'");
    }

    //for debugging purposes
    string toString() const
    {
        char[bits / 3 + 1] buffer;
        size_t i = buffer.length;
        THIS v = this;
        do
        {
            auto r = divrem(v, 10U);
            buffer[--i] = cast(char)('0' + cast(uint)r);
        } while (v != 0U);
        return buffer[i .. $].dup;
    }

}

alias uint128 = unsigned!128;
alias uint256 = unsigned!256;
alias uint512 = unsigned!512;

unittest
{
    import std.typetuple;
    import std.random;
    
    auto gen = Random();

    T rnd(T)()
    {
        static if (is(T == uint))
            return uniform(1U, uint.max, gen);
        else static if (is(T == ulong))
            return uniform(1UL, ulong.max, gen);
        else
            return T(rnd!(T.HALF)(), rnd!(T.HALF)());

    }




    foreach (T; TypeTuple!(unsigned!128, unsigned!256, unsigned!512))
    {
        enum zero = T(0U);
        enum one = T(1U);
        enum two = T(2U);
        enum three = T(3U);
        enum big = T(0x3333333333U, 0x4444444444U);
        enum next = T(1U, 0U);
        enum previous = T(0U, T.HALF.max);

        assert (zero == zero);
        assert (zero <= zero);
        assert (zero >= zero);
        assert (zero < one);
        assert (zero < two);
        assert (zero < three);
        assert (zero < big);
        assert (zero < next);
        assert (zero < previous);

        assert (one > zero);
        assert (one >= zero);
        assert (one >= one);
        assert (one == one);
        assert (one < two);
        assert (one < three);
        assert (one < big);
        assert (one < next);
        assert (one < previous);

        assert (two > zero);
        assert (two >= zero);
        assert (two >= one);
        assert (two > one);
        assert (two == two);
        assert (two < three);
        assert (two < big);
        assert (two < next);
        assert (two < previous);

        assert (three > zero);
        assert (three >= zero);
        assert (three >= one);
        assert (three > one);
        assert (three >= two);
        assert (three == three);
        assert (three < big);
        assert (three < next);
        assert (three < previous);

        assert (big > zero);
        assert (big >= zero);
        assert (big >= one);
        assert (big > one);
        assert (big >= two);
        assert (big >= three);
        assert (big == big);
        assert (big > next);
        assert (big > previous);

        assert (next > zero);
        assert (next >= zero);
        assert (next >= one);
        assert (next > one);
        assert (next >= two);
        assert (next >= three);
        assert (next <= big);
        assert (next == next);
        assert (next > previous);

        assert (previous > zero);
        assert (previous >= zero);
        assert (previous >= one);
        assert (previous > one);
        assert (previous >= two);
        assert (previous >= three);
        assert (previous <= big);
        assert (previous <= next);
        assert (previous == previous);

        assert (zero == 0U);
        assert (zero <= 0U);
        assert (zero >= 0U);
        assert (zero < 1U);
        assert (zero < 2U);
        assert (zero < 3U);
        assert (zero < ulong.max);

        assert (one > 0U);
        assert (one >= 0U);
        assert (one >= 1U);
        assert (one == 1U);
        assert (one < 2U);
        assert (one < 3U);
        assert (one < ulong.max);

        assert (two > 0U);
        assert (two >= 0U);
        assert (two >= 1U);
        assert (two > 1U);
        assert (two == 2U);
        assert (two < 3U);
        assert (two < ulong.max);

        assert (three > 0U);
        assert (three >= 0U);
        assert (three >= 1U);
        assert (three > 1U);
        assert (three >= 2U);
        assert (three == 3U);
        assert (three < ulong.max);

        assert (big > 0U);
        assert (big >= 0U);
        assert (big >= 1U);
        assert (big > 1U);
        assert (big >= 2U);
        assert (big >= 3U);
        assert (big > ulong.max);

        assert (next > 0U);
        assert (next >= 0U);
        assert (next >= 1U);
        assert (next > 1U);
        assert (next >= 2U);
        assert (next >= 3U);
        assert (next > ulong.max);

        assert (previous > 0U);
        assert (previous >= 0U);
        assert (previous >= 1U);
        assert (previous > 1U);
        assert (previous >= 2U);
        assert (previous >= 3U);
        assert (previous == previous);

        assert (~~zero == zero);
        assert (~~one == one);
        assert (~~two == two);
        assert (~~three == three);
        assert (~~big == big);
        assert (~~previous == previous);
        assert (~~next == next);

        assert ((one | one) == one);
        assert ((one | zero) == one);
        assert ((one & one) == one);
        assert ((one & zero) == zero);
        assert ((big & ~big) == zero);
        assert ((one ^ one) == zero);
        assert ((big ^ big) == zero);
        assert ((one ^ zero) == one);

        assert(big >> 0 == big);
        assert(big << 0 == big);

        assert(big << 1 > big);
        assert(big >> 1 < big);

        auto x = big << 3;
        auto y = x >> 3;
        assert((big << 3) >> 3 == big);
        assert((one << 127) >> 127 == one);
        assert((one << 64) >> 64 == one);

        assert (zero + zero == zero);
        assert (zero + one == one);
        assert (zero + two == two);
        assert (zero + three == three);
        assert (zero + big == big);
        assert (zero + previous == previous);
        assert (zero + next == next);

        assert (one + zero == one);
        assert (one + one == two);
        assert (one + two == three);
        assert (one + three > three);
        assert (one + big > big);
        assert (one + previous == next);
        assert (one + next > next);

        assert (two + zero == two);
        assert (two + one == three);
        assert (two + two > three);
        assert (two + three > three);
        assert (two + big > big);
        assert (two + previous > next);
        assert (two + next > next);

        assert (three + zero == three);
        assert (three + one > three);
        assert (three + two > three);
        assert (three + three > three);
        assert (three + big > big);
        assert (three + previous > next);
        assert (three + next > next);

        assert (big + zero == big);
        assert (big + one > big);
        assert (big + two > big + one);
        assert (big + three > big + two);
        assert (big + big > big);
        assert (big + previous > next);
        assert (big + next > next);

        assert (previous + zero == previous);
        assert (previous + one == next);
        assert (previous + two > next);
        assert (previous + three == next + two);
        assert (previous + big > big);
        assert (previous + previous > previous);
        assert (previous + next > previous);

        assert (next + zero == next);
        assert (next + one > next);
        assert (next + two > next);
        assert (next + three >= next + two);
        assert (next + big > big);
        assert (next + previous > next);
        assert (next + next > next);

        assert (zero + 0U == zero);
        assert (zero + 1U == one);
        assert (zero + 2U == two);
        assert (zero + 3U == three);

        assert (one + 0U == one);
        assert (one + 1U == two);
        assert (one + 2U == three);
        assert (one + 3U > three);

        assert (two + 0U == two);
        assert (two + 1U == three);
        assert (two + 2U > three);
        assert (two + 3U > three);

        assert (three + 0U == three);
        assert (three + 1U > three);
        assert (three + 2U > three);
        assert (three + 3U > three);

        assert (big + 0U == big);
        assert (big + 1U > big);
        assert (big + 2U > big + 1U);
        assert (big + 3U > big + 2U);

        assert (previous + 0U == previous);
        assert (previous + 1U == next);
        assert (previous + 2U > next);
        assert (previous + 3U == next + 2U);

        assert (next + 0U == next);
        assert (next + 1U > next);
        assert (next + 2U > next);
        assert (next + 3U >= next + two);

        assert (zero - zero == zero);
        assert (one - zero == one);
        assert (two - zero == two);
        assert (three - zero == three);
        assert (big - zero == big);
        assert (previous - zero == previous);
        assert (next - zero == next);

        assert (one - one == zero);
        assert (two - one == one);
        assert (three - one == two);
        assert (big - one < big);
        assert (previous - one < previous);
        assert (next - one == previous);

        assert (two - two == zero);
        assert (three - two == one);
        assert (big - two < big);
        assert (previous - two < previous);
        assert (next - two < previous);

        assert (three - three == zero);
        assert (big - three < big);
        assert (previous - three < previous);
        assert (next - three < previous);

        assert (big - big == zero);
        assert (next - previous == one);

        assert (one - 1U == zero);
        assert (two - 1U == one);
        assert (three - 1U == two);
        assert (big - 1U < big);
        assert (previous - 1U < previous);
        assert (next - 1U == previous);

        assert (two - 2U == zero);
        assert (three - 2U == one);
        assert (big - 2U < big);
        assert (previous - 2U < previous);
        assert (next - 2U < previous);

        assert (three - 3U == zero);
        assert (big - 3U < big);
        assert (previous - 3U < previous);
        assert (next - 3U < previous);

        T test = zero;
        assert (++test == one);
        assert (++test == two);
        assert (++test == three);
        test = big;
        assert (++test > big);
        test = previous;
        assert (++test == next);
        test = three;
        assert (--test == two);
        assert (--test == one);
        assert (--test == zero);
        test = big;
        assert (--test < big);
        test = next;
        assert (--test == previous);

        assert (-zero == zero);
        assert (-(-zero) == zero);
        assert (-(-one) == one);
        assert (-(-two) == two);
        assert (-(-three) == three);
        assert (-(-big) == big);
        assert (-(-previous) == previous);
        assert (-(-next) == next);


        for(auto i = 0; i < 10; ++i)
        {
            T a = rnd!T();
            T b = rnd!T();
            T.HALF c = rnd!(T.HALF)();
            ulong d = rnd!ulong();
            uint e = rnd!uint();

            T result = a / b;
            T remainder = a % b;

            assert (result * b + remainder == a);

            result = a / c;
            remainder = a % c;

            assert (result * c + remainder == a);

            result = a / d;
            remainder = a % d;

            assert (result * d + remainder == a);

            result = a / e;
            remainder = a % e;

            assert (result * e + remainder == a);
        }
    }

}



/* ****************************************************************************************************************** */
/* INTEGRAL UTILITY FUNCTIONS                                                                                         */
/* ****************************************************************************************************************** */

@safe pure nothrow @nogc
uint xadd(ref uint x, const uint y)
{
    bool ovf;
    x = addu(x, y, ovf);
    return ovf ? 1 : 0;
}

@safe pure nothrow @nogc
uint xadd(ref ulong x, const ulong y)
{
    bool ovf;
    x = addu(x, y, ovf);
    return ovf ? 1 : 0;
}

@safe pure nothrow @nogc
uint xadd(ref ulong x, const uint y)
{
    return xadd(x, cast(ulong)y);
}

uint xadd(T)(ref T x, auto const ref T y) 
if (isCustomUnsigned!T)
{
    auto carry = xadd(x.lo, y.lo);
    carry = xadd(x.hi, carry);
    return xadd(x.hi, y.hi) + carry;
}

uint xadd(T, U)(ref T x, auto const ref U y) 
if (isCustomUnsigned!T && isUnsignedAssignable!(T.HALF, U))
{
    auto carry = xadd(x.lo, y);
    return xadd(x.hi, carry);
}

@safe pure nothrow @nogc
uint xsub(ref uint x, const uint y)
{
    bool ovf;
    x = subu(x, y, ovf);
    return ovf ? 1 : 0;
}

@safe pure nothrow @nogc
uint xsub(ref ulong x, const ulong y)
{
    bool ovf;
    x = subu(x, y, ovf);
    return ovf ? 1 : 0;
}

@safe pure nothrow @nogc
uint xsub(ref ulong x, const uint y)
{
    return xsub(x, cast(ulong)y);
}

@safe pure nothrow @nogc
uint xsub(T)(ref T x, auto const ref T y) 
if (isCustomUnsigned!T)
{
    auto carry = xsub(x.lo, y.lo);
    carry = xsub(x.hi, carry);
    return xsub(x.hi, y.hi) + carry;
}

@safe pure nothrow @nogc
uint xsub(T, U)(ref T x, auto const ref U y) 
if (isCustomUnsigned!T && isUnsignedAssignable!(T.HALF, U))
{
    auto carry = xsub(x.lo, y);
    return xsub(x.hi, carry);
}

@safe pure nothrow @nogc
uint fma(const uint x, const uint y, const uint z, out bool overflow)
{
    auto result = mulu(x, y, overflow);
    return addu(result, z, overflow);
}

@safe pure nothrow @nogc
ulong fma(const ulong x, const ulong y, const ulong z, ref bool overflow)
{
    auto result = mulu(x, y, overflow);
    return addu(result, z, overflow);
}

@safe pure nothrow @nogc
ulong fma(const ulong x, const uint y, const uint z, ref bool overflow)
{
    auto result = mulu(x, cast(ulong)y, overflow);
    return addu(result, cast(ulong)z, overflow);
}

@safe pure nothrow @nogc
T fma(T)(auto const ref T x, auto const ref T y, auto const ref T z, ref bool overflow)
if (isCustomUnsigned!T)
{
    auto result = mulu(x, y, overflow);
    if (xadd(result, z))
        overflow = true;
    return result;
}

@safe pure nothrow @nogc
T fma(T, U)(auto const ref T x, auto const ref U y, auto const ref U z, ref bool overflow)
if (isCustomUnsigned!T && isUnsignedAssignable!(T.HALF, U))
{
    auto result = mulu(x, y, overflow);
    if (xadd(result, z))
        overflow = true;
    return result;
}


@safe pure nothrow @nogc
ulong xmul(const uint x, const uint y)
{
    return cast(ulong)x * y;
}

@safe pure nothrow @nogc
ulong xsqr(const uint x)
{
    return cast(ulong)x * x;
}

@safe pure nothrow @nogc
uint128 xmul(const ulong x, const ulong y)
{
    if (x == 0 || y == 0)
        return uint128.min;
    if (x == 1)
        return uint128(y);
    if (y == 1)
        return uint128(x);
    if ((x & (x - 1)) == 0)
        return uint128(y) << ctz(x);
    if ((y & (y - 1)) == 0)
        return uint128(x) << ctz(y);
    if (x == y)
        return xsqr(x);


    immutable xlo = cast(uint)x;
    immutable xhi = cast(uint)(x >>> 32);
    immutable ylo = cast(uint)y;
    immutable yhi = cast(uint)(y >>> 32);

    ulong t = xmul(xlo, ylo);
    ulong w0 = cast(uint)t;
    ulong k = t >>> 32;

    t = xmul(xhi, ylo) + k;
    ulong w1 = cast(uint)t;
    ulong w2 = t >>> 32;

    t = xmul(xlo, yhi) + w1;
    k = t >>> 32;

    return uint128(xmul(xhi, yhi) + w2 + k, (t << 32) + w0);
}

@safe pure nothrow @nogc
uint128 xsqr(const ulong x)
{
    immutable xlo = cast(uint)x;
    immutable xhi = cast(uint)(x >>> 32);
    immutable hilo = xmul(xlo, xhi);

    ulong t = xsqr(xlo);
    ulong w0 = cast(uint)t;
    ulong k = t >>> 32;

    t = hilo + k;
    ulong w1 = cast(uint)t;
    ulong w2 = t >>> 32;

    t = hilo + w1;
    k = t >>> 32;

    return uint128(xsqr(xhi) + w2 + k, (t << 32) + w0);
}

@safe pure nothrow @nogc
uint128 xmul(const ulong x, const uint y)
{
    if (x == 0 || y == 0)
        return uint128.min;
    if (x == 1)
        return uint128(y);
    if (y == 1)
        return uint128(x);
    if ((x & (x - 1)) == 0)
        return uint128(y) << ctz(x);
    if ((y & (y - 1)) == 0)
        return uint128(x) << ctz(y);

    immutable xlo = cast(uint)x;
    immutable xhi = cast(uint)(x >>> 32);

    ulong t = xmul(xlo, y);
    ulong w0 = cast(uint)t;
    ulong k = t >>> 32;

    t = xmul(xhi, y) + k;
    ulong w1 = cast(uint)t;
    ulong w2 = t >>> 32;

    return uint128(w2, (w1 << 32) + w0);
}


auto xmul(T)(auto const ref T x, auto const ref T y)
if (isCustomUnsigned!T)
{
    enum bits = T.sizeof * 8;
    enum rbits = bits * 2;
    alias R = unsigned!rbits;
  
    if (x == 0U || y == 0U)
        return R.min;
    if (x == 1U)
        return R(y);
    if (y == 1U)
        return R(x);
    if ((x & (x - 1U)) == 0U)
        return R(y) << ctz(x);
    if ((y & (y - 1U)) == 0U)
        return R(x) << ctz(y);
    if (x == y)
        return xsqr(x);

    auto t = xmul(x.lo, y.lo);
    auto w0 = t.lo;
    auto k = t.hi;

    t = xmul(x.hi, y.lo) + k;
    auto w2 = t.hi;

    t = xmul(x.lo, y.hi) + t.lo;

    return R(xmul(x.hi, y.hi) + w2 + t.hi, (t << (bits / 2)) + w0);
}

T mulu(T)(auto const ref T x, auto const ref T y, ref bool overflow)
if (isCustomUnsigned!T)
{
    enum bits = T.sizeof * 8;

    if (x == 0U || y == 0U)
        return T.min;
    if (x == 1)
        return y;
    if (y == 1)
        return x;
    if ((x & (x - 1)) == 0U)
    {
        auto lz = clz(y);
        auto shift = ctz(x);
        if (lz < shift)
            overflow = true;
        return y << shift;
    }
    if ((y & (y - 1)) == 0U)
    {
        auto lz = clz(x);
        auto shift = ctz(y);
        if (lz < shift)
            overflow = true;
        return x << shift;
    }
    if (x == y)
        return sqru(x, overflow);

    auto t = xmul(x.lo, y.lo);
    auto w0 = t.lo;
    auto k = t.hi;

    t = xmul(x.hi, y.lo) + k;
    auto w2 = t.hi;

    t = xmul(x.lo, y.hi) + t.lo;

    if (w2 || t.hi)
        overflow = true;
    else if (xmul(x.hi, y.hi))
        overflow = true;

    return (t << (bits / 2)) + w0;
}

auto xsqr(T)(auto const ref T x)
if (isCustomUnsigned!T)
{

    enum bits = T.sizeof * 8;
    enum rbits = bits * 2;
    alias R = unsigned!rbits;

    immutable hilo = xmul(x.lo, x.hi);

    auto t = xsqr(x.lo);
    auto w0 = t.lo;
    auto k = t.hi;

    t = hilo + k;
    auto w2 = t.hi;

    t = hilo + t.lo;

    return R(xsqr(x.hi) + w2 + t.hi, (t << (bits / 2)) + w0);
}

T sqru(T)(auto const ref T x, ref bool overflow)
if (isCustomUnsigned!T)
{
    enum bits = T.sizeof * 8;

    immutable hilo = xmul(x.lo, x.hi);
    auto t = xsqr(x.lo);
    auto w0 = t.lo;
    auto k = t.hi;

    t = hilo + k;
    auto w2 = t.hi;

    t = hilo + t.lo;

    if (w2 || t.hi)
        overflow = true;
    else if (xhi)
        overflow = true;

    return (t << (bits / 2)) + w0;
}

auto xmul(T, U)(auto const ref T x, auto const ref U y)
if (isCustomUnsigned!T && isUnsignedAssignable!(T.HALF, U))
{

    enum bits = T.sizeof * 8;
    enum rbits = bits * 2;
    alias R = unsigned!rbits;

    if (x == 0U || y == 0U)
        return R.min;
    if (x == 1U)
        return R(y);
    if (y == 1U)
        return R(x);
    if ((x & (x - 1U)) == 0U)
        return R(y) << ctz(x);
    if ((y & (y - 1U)) == 0U)
        return R(x) << ctz(y);

    auto t = xmul(x.lo, y);
    auto w0 = t.lo;
    auto k = t.hi;

    t = xmul(x.hi, y) + k;
    auto w2 = t.hi;

    t = t.lo;

    return R(w2, (t << (bits / 2)) + w0);
}

T mulu(T, U)(auto const ref T x, auto const ref U y, ref bool overflow)
if (isCustomUnsigned!T && isUnsignedAssignable!(T.HALF, U))
{

    enum bits = T.sizeof * 8;

    if (x == 0U || y == 0U)
        return T.min;
    if (x == 1U)
        return T(y);
    if (y == 1U)
        return x;
    if ((x & (x - 1U)) == 0U)
    {
        auto yy = T(y);
        auto lz = clz(y);
        auto shift = ctz(x);
        if (lz < shift)
            overflow = true;
        return yy << shift;
    }
    if ((y & (y - 1)) == 0U)
    {
        auto lz = clz(x);
        auto shift = ctz(y);
        if (lz < shift)
            overflow = true;
        return x << shift;
    }

    auto t = xmul(x.lo, y);
    auto w0 = t.lo;
    auto k = t.hi;

    t = xmul(x.hi, y) + k;
    
    if (t.hi)
        overflow = true;

    t = t.lo;

    return (t << (bits / 2)) + w0;
}

@safe pure nothrow @nogc
auto clz(const uint x)
{
    return x ? 31 - bsr(x) : 0;
}

@safe pure nothrow @nogc
auto clz(const ulong x)
{
    if (!x)
        return 64;
    static if (is(size_t == ulong))
        return 63 - bsr(x);
    else static if(is(size_t == uint))
    {
        immutable hi = cast(uint)(x >> 32);
        if (hi)
            return 31 - bsr(hi);
        else
            return 63 - bsr(cast(uint)x);
    }
    else
        static assert(0);
}

auto clz(T)(auto const ref T x)
if (isCustomUnsigned!T)
{
    enum bits = T.sizeof * 8;
    auto ret = clz(x.hi);
    return ret == bits / 2 ? ret + clz(x.lo) : ret;
}

@safe pure nothrow @nogc
auto ctz(const uint x)
{
    return x ? bsf(x) : 0;
}

@safe pure nothrow @nogc
auto ctz(const ulong x)
{
    if (!x)
        return 64;
    static if (is(size_t == ulong))
        return bsf(x);
    else static if (is(size_t == uint))
    {
        immutable lo = cast(uint)x;
        if (lo)
            return bsf(lo);
        else
            return bsf(cast(uint)(x >> 32)) + 32;
    }
    else
        static assert(0);
}

auto ctz(T)(auto const ref T x)
if (isCustomUnsigned!T)
{
    enum bits = T.sizeof * 8;
    auto ret = ctz(x.lo);
    return ret == bits / 2 ? ret + ctz(x.hi) : ret;
}

bool ispow2(T)(auto const ref T x)
if (isAnyUnsigned!T)
{
    return x != 0U && (x & (x - 1U)) == 0;
}

bool ispow10(T)(auto const ref T x)
if (isAnyUnsigned!T)
{
    if (x == 0U)
        return false;

    for (size_t i = 0; i < pow10!T.length; ++i)
    {
        if (x == pow10!T[i])
            return true;
        else if (x < pow10!T[i])
            return false;
    }
    return false;
}




@safe pure nothrow @nogc
uint divrem(ref uint x, const uint y)
{
    uint ret = x % y;
    x /= y;
    return ret;
}

@safe pure nothrow @nogc
ulong divrem(ref ulong x, const ulong y)
{
    ulong ret = x % y;
    x /= y;
    return ret;
}

@safe pure nothrow @nogc
ulong divrem(ref ulong x, const uint y)
{
    ulong ret = x % y;
    x /= y;
    return ret;
}

T divrem(T)(ref T x, auto const ref T y)
if (isCustomUnsigned!T)
{
    Unqual!T r;
    int shift;

    if (!x.hi)
    {
        if (!y.hi)
            return Unqual!T(divrem(x.lo, y.lo));
        r.lo = x.lo;
        x.lo = 0U;
        return r;
    }

    if (!y.lo)
    {
        if (!y.hi)
            return Unqual!T(divrem(x.hi, y.lo));
        if (!x.lo)
        {
            r.hi = divrem(x.hi, y.hi);
            x.lo = x.hi;
            x.hi = 0U;
            return r;
        }
        if ((y.hi & (y.hi - 1U)) == 0U)
        {
            r.lo = x.lo;
            r.hi = x.hi & (y.hi - 1U);
            x.lo = x.hi >>> ctz(y.hi);
            x.hi = 0U;
            return r;
        }
        shift = clz(y.hi) - clz(x.hi);
        if (shift > T.HALF.sizeof * 8 - 2)
        {
            r = x;
            x = 0U;
            return r;
        }        
    }
    else
    {
        if (!y.hi)
        {
            if ((y.lo & (y.lo - 1U)) == 0U)
            {
                r.lo = x.lo & (y.lo - 1U);
                if (y.lo == 1U)
                    return r;
                x >>= ctz(y.lo);
                return r;
            }
        }
        else
        {
            shift = clz(y.hi) - clz(x.hi);
            if (shift > T.HALF.sizeof * 8 - 1)
            {
                r = x;
                x = 0U;
                return r;
            }
        }
    }

    r = x;
    T d = y;
    T z = 1U;
    x = 0U;

    shift = clz(d);

    z <<= shift;
    d <<= shift;

    while(z)
    {
        if (r >= d)
        {
            r -= d;
            x |= z;
        }
        z >>= 1;
        d >>= 1;
    }

    return r;
}

T divrem(T, U)(ref T x, auto const ref U y)
if (isCustomUnsigned!T && isUnsignedAssignable!(T.HALF, U))
{
    Unqual!T r;
    int shift;

    if (!x.hi)
        return Unqual!T(divrem(x.lo, y));
 
    if (!y)
        return Unqual!T(divrem(x.hi, y));
     
    if ((y & (y - 1U)) == 0U)
    {
        r.lo = x.lo & (y - 1U);
        if (y == 1U)
            return r;
        x >>= ctz(y);
        return r;
    }
    

    r = x;
    T d = y;
    T z = 1U;
    x = 0U;

    shift = clz(d);

    z <<= shift;
    d <<= shift;

    while(z)
    {
        if (r >= d)
        {
            r -= d;
            x |= z;
        }
        z >>= 1;
        d >>= 1;
    }

    return r;
}

int prec(T)(const T x) 
if (isUnsigned!T || is(T : uint128) || is(T : uint256) || is(T : uint512))
{
    static foreach_reverse(i, p; pow10!T)
    {
        if (x >= p)
            return i + 1;
    }
    return 0;
}

//returns power of 10 if x is power of 10, -1 otherwise
@safe pure nothrow @nogc
int getPow10(T)(auto const ref T x) 
if (isUnsigned!T || is(T : uint128) || is(T : uint256))
{
    static foreach_reverse(i, p; pow10!T)
    {
        if (x == p)
            return i + 1;
        else if (x < p)
            return -1;
    }
    return 0;
}

T cvt(T, U)(auto const ref U value)
if (isAnyUnsigned!T && isAnyUnsigned!U)
{
    static if (T.sizeof > U.sizeof)
        return (T(value));
    else static if (T.sizeof < U.sizeof)
        return cast(T)(value);
    else
        return value;
}

auto sign(S, U)(const U u, const bool isNegative)
if (isUnsigned!U && isSigned!S)
{
    static if (is(U: ubyte) || is(U: ushort))
        return isNegative ? cast(S)-cast(int)u : cast(S)u;
    else static if (is(S: byte) || is(S: short))
        return isNegative ? cast(S)-cast(int)u : cast(S)u;
    else
        return isNegative ? -cast(S)u : cast(S)u;
}

unittest
{
    static assert (sign!byte(ubyte(128), true) == byte.min);
    static assert (sign!byte(ushort(128), true) == byte.min);
    static assert (sign!byte(uint(128), true) == byte.min);
    static assert (sign!byte(ulong(128), true) == byte.min);

    static assert (sign!short(ubyte(128), true) == byte.min);
    static assert (sign!short(ushort(32768), true) == short.min);
    static assert (sign!short(uint(32768), true) == short.min);
    static assert (sign!short(ulong(32768), true) == short.min);


    static assert (sign!int(ubyte(128), true) == byte.min);
    static assert (sign!int(ushort(32768), true) == short.min);
    static assert (sign!int(uint(2147483648), true) == int.min);
    static assert (sign!int(ulong(2147483648), true) == int.min);
    
    static assert (sign!long(ubyte(128), true) == byte.min);
    static assert (sign!long(ushort(32768), true) == short.min);
    static assert (sign!long(uint(2147483648), true) == int.min);
    static assert (sign!long(ulong(9223372036854775808UL), true) == long.min);

}

auto sign(S, U)(const U u, const bool isNegative)
if (isCustomUnsigned!U && isSigned!S)
{
     return isNegative ? cast(S)-cast(ulong)u : cast(S)cast(ulong)u;
}

auto unsign(U, S)(const S s, out bool isNegative)
if (isUnsigned!U && isSigned!S)
{
    isNegative = s < 0;
    static if (is(S: byte) || is(S: short))
        return isNegative ? cast(U)-cast(int)s : cast(U)s;
    else static if (is(U: ubyte) || is(U: ushort))
        return isNegative ? cast(U)-cast(int)s : cast(U)s;
    else
        return isNegative? -cast(U)s: cast(U)s;
}

unittest
{

    static assert (unsign!ubyte(byte.min) == 128);
    static assert (unsign!ubyte(short(-128)) == 128);
    static assert (unsign!ubyte(int(-128)) == 128);
    static assert (unsign!ubyte(long(-128)) == 128);

    static assert (unsign!ushort(byte.min) == 128);
    static assert (unsign!ushort(short.min) == 32768);
    static assert (unsign!ushort(int(short.min)) == 32768);
    static assert (unsign!ushort(long(short.min)) == 32768);

    static assert (unsign!uint(byte.min) == 128);
    static assert (unsign!uint(short.min) == 32768);
    static assert (unsign!uint(int.min) == 2147483648);
    static assert (unsign!uint(long(int.min)) == 2147483648);

    static assert (unsign!ulong(byte.min) == 128);
    static assert (unsign!ulong(short.min) == 32768);
    static assert (unsign!ulong(int.min) == 2147483648);
    static assert (unsign!ulong(long.min) == 9223372036854775808UL);


}

auto unsign(U, V)(const V v, out bool isNegative)
if (isUnsigned!U && isUnsigned!V)
{
    isNegative = false;
    return cast(U)v;
}

auto unsign(U, V)(const V v, out bool isNegative)
if (isCustomUnsigned!U && isUnsigned!V)
{
    isNegative = false;
    return U(v);
}

auto unsign(U, S)(const S s)
if (isUnsigned!U && isSigned!S)
{
    static if (is(S: byte) || is(S: short))
        return s < 0 ? cast(U)-cast(int)s : cast(U)s;
    else static if (is(U: ubyte) || is(U: ushort))
        return s < 0 ? cast(U)-cast(int)s : cast(U)s;
    else
        return s < 0 ? -cast(U)s: cast(U)s;
}



auto unsign(U, S)(const S s, out bool isNegative)
if (isCustomUnsigned!U && isSigned!S)
{
    isNegative = s < 0;
    static if (is(S: byte) || is(S: short))
        return isNegative ? U(cast(uint)-cast(int)s) : U(cast(uint)s);
    else static if (is(S: int))
        return isNegative ? U(cast(ulong)(-cast(long)s)) : U(cast(uint)s);
    else
        return isNegative ? U(cast(ulong)-s) : U(cast(ulong)s);
}

auto unsign(U, S)(const S s)
if (isCustomUnsigned!U && isSigned!S)
{
    static if (is(S: byte) || is(S: short))
        return s < 0 ? U(cast(uint)-cast(int)s) : U(cast(uint)s);
    else static if (is(S: int))
        return s < 0 ? U(cast(ulong)(-cast(long)s)) : U(cast(uint)s);
    else
        return s < 0 ? U(cast(ulong)-s) : U(cast(ulong)s);
}






pure @safe nothrow @nogc
int cappedSub(ref int target, const int value)
{
    bool ovf;
    int result = subs(target, value, ovf);
    if (ovf)
    {
        if (value > 0)
        {
            //target was negative
            result = target - int.min;
            target = int.min;
        }
        else
        {
            //target was positive
            result = target - int.max;
            target = int.max;
        }
        return result;
    }
    else
    {
        target -= value;
        return value;
    }
}

pure @safe nothrow @nogc
int cappedAdd(ref int target, const int value)
{
    bool ovf;
    int result = adds(target, value, ovf);
    if (ovf)
    {
        if (value > 0)
        {
            //target was positive
            result = int.max - target;
            target = int.max;      
        }
        else
        {
            //target was negative
            result = int.min - target;
            target = int.min;
        }
        return result;
    }
    else
    {
        target += value;
        return value;
    }
}

unittest
{
    int ex = int.min + 1;
    int px = cappedSub(ex, 3);
    assert (ex == int.min);
    assert (px == 1);

    ex = int.min + 3;
    px = cappedSub(ex, 2);
    assert (ex == int.min + 1);
    assert (px == 2);

    ex = int.max - 1;
    px = cappedSub(ex, -2);
    assert (ex == int.max);
    assert (px == -1);

    ex = int.max - 3;
    px = cappedSub(ex, -2);
    assert (ex == int.max - 1);
    assert(px == -2);


}

/* ****************************************************************************************************************** */
/* 10-POWER CONSTANTS                                                                                                 */
/* ****************************************************************************************************************** */

immutable ubyte[3] pow10_8 =
[
    1U,
    10U,
    100U,
];

immutable ushort[5] pow10_16 =
[
    1U,
    10U,
    100U,
    1000U,
    10000U,
];

immutable uint[10] pow10_32 =
[
    1U,
    10U,
    100U,
    1000U,
    10000U,
    100000U,
    1000000U,
    10000000U,
    100000000U,
    1000000000U
];

immutable ulong[20] pow10_64 =
[
    1UL,
    10UL,
    100UL,
    1000UL,
    10000UL,
    100000UL,
    1000000UL,
    10000000UL,
    100000000UL,
    1000000000UL,
    10000000000UL,
    100000000000UL,
    1000000000000UL,
    10000000000000UL,
    100000000000000UL,
    1000000000000000UL,
    10000000000000000UL,
    100000000000000000UL,
    1000000000000000000UL,
    10000000000000000000UL,
];

immutable uint128[39] pow10_128 =
[
    uint128(1UL),
    uint128(10UL),
    uint128(100UL),
    uint128(1000UL),
    uint128(10000UL),
    uint128(100000UL),
    uint128(1000000UL),
    uint128(10000000UL),
    uint128(100000000UL),
    uint128(1000000000UL),
    uint128(10000000000UL),
    uint128(100000000000UL),
    uint128(1000000000000UL),
    uint128(10000000000000UL),
    uint128(100000000000000UL),
    uint128(1000000000000000UL),
    uint128(10000000000000000UL),
    uint128(100000000000000000UL),
    uint128(1000000000000000000UL),
    uint128(10000000000000000000UL),
    uint128("100000000000000000000"),
    uint128("1000000000000000000000"),
    uint128("10000000000000000000000"),
    uint128("100000000000000000000000"),
    uint128("1000000000000000000000000"),
    uint128("10000000000000000000000000"),
    uint128("100000000000000000000000000"),
    uint128("1000000000000000000000000000"),
    uint128("10000000000000000000000000000"),
    uint128("100000000000000000000000000000"),
    uint128("1000000000000000000000000000000"),
    uint128("10000000000000000000000000000000"),
    uint128("100000000000000000000000000000000"),
    uint128("1000000000000000000000000000000000"),
    uint128("10000000000000000000000000000000000"),
    uint128("100000000000000000000000000000000000"),
    uint128("1000000000000000000000000000000000000"),
    uint128("10000000000000000000000000000000000000"),
    uint128("100000000000000000000000000000000000000"),
];

immutable uint256[78] pow10_256 =
[
    uint256(1UL),
    uint256(10UL),
    uint256(100UL),
    uint256(1000UL),
    uint256(10000UL),
    uint256(100000UL),
    uint256(1000000UL),
    uint256(10000000UL),
    uint256(100000000UL),
    uint256(1000000000UL),
    uint256(10000000000UL),
    uint256(100000000000UL),
    uint256(1000000000000UL),
    uint256(10000000000000UL),
    uint256(100000000000000UL),
    uint256(1000000000000000UL),
    uint256(10000000000000000UL),
    uint256(100000000000000000UL),
    uint256(1000000000000000000UL),
    uint256(10000000000000000000UL),
    uint256("100000000000000000000"),
    uint256("1000000000000000000000"),
    uint256("10000000000000000000000"),
    uint256("100000000000000000000000"),
    uint256("1000000000000000000000000"),
    uint256("10000000000000000000000000"),
    uint256("100000000000000000000000000"),
    uint256("1000000000000000000000000000"),
    uint256("10000000000000000000000000000"),
    uint256("100000000000000000000000000000"),
    uint256("1000000000000000000000000000000"),
    uint256("10000000000000000000000000000000"),
    uint256("100000000000000000000000000000000"),
    uint256("1000000000000000000000000000000000"),
    uint256("10000000000000000000000000000000000"),
    uint256("100000000000000000000000000000000000"),
    uint256("1000000000000000000000000000000000000"),
    uint256("10000000000000000000000000000000000000"),
    uint256("100000000000000000000000000000000000000"),
    uint256("1000000000000000000000000000000000000000"),
    uint256("10000000000000000000000000000000000000000"),
    uint256("100000000000000000000000000000000000000000"),
    uint256("1000000000000000000000000000000000000000000"),
    uint256("10000000000000000000000000000000000000000000"),
    uint256("100000000000000000000000000000000000000000000"),
    uint256("1000000000000000000000000000000000000000000000"),
    uint256("10000000000000000000000000000000000000000000000"),
    uint256("100000000000000000000000000000000000000000000000"),
    uint256("1000000000000000000000000000000000000000000000000"),
    uint256("10000000000000000000000000000000000000000000000000"),
    uint256("100000000000000000000000000000000000000000000000000"),
    uint256("1000000000000000000000000000000000000000000000000000"),
    uint256("10000000000000000000000000000000000000000000000000000"),
    uint256("100000000000000000000000000000000000000000000000000000"),
    uint256("1000000000000000000000000000000000000000000000000000000"),
    uint256("10000000000000000000000000000000000000000000000000000000"),
    uint256("100000000000000000000000000000000000000000000000000000000"),
    uint256("1000000000000000000000000000000000000000000000000000000000"),
    uint256("10000000000000000000000000000000000000000000000000000000000"),
    uint256("100000000000000000000000000000000000000000000000000000000000"),
    uint256("1000000000000000000000000000000000000000000000000000000000000"),
    uint256("10000000000000000000000000000000000000000000000000000000000000"),
    uint256("100000000000000000000000000000000000000000000000000000000000000"),
    uint256("1000000000000000000000000000000000000000000000000000000000000000"),
    uint256("10000000000000000000000000000000000000000000000000000000000000000"),
    uint256("100000000000000000000000000000000000000000000000000000000000000000"),
    uint256("1000000000000000000000000000000000000000000000000000000000000000000"),
    uint256("10000000000000000000000000000000000000000000000000000000000000000000"),
    uint256("100000000000000000000000000000000000000000000000000000000000000000000"),
    uint256("1000000000000000000000000000000000000000000000000000000000000000000000"),
    uint256("10000000000000000000000000000000000000000000000000000000000000000000000"),
    uint256("100000000000000000000000000000000000000000000000000000000000000000000000"),
    uint256("1000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint256("10000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint256("100000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint256("1000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint256("10000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint256("100000000000000000000000000000000000000000000000000000000000000000000000000000"),
];

immutable uint512[155] pow10_512 =
[
    uint512(1UL),  //0  - 2074
    uint512(10UL),  //1  - 2075
    uint512(100UL),
    uint512(1000UL),
    uint512(10000UL),
    uint512(100000UL),
    uint512(1000000UL),
    uint512(10000000UL),
    uint512(100000000UL),
    uint512(1000000000UL),
    uint512(10000000000UL),
    uint512(100000000000UL),
    uint512(1000000000000UL),
    uint512(10000000000000UL),
    uint512(100000000000000UL),
    uint512(1000000000000000UL),
    uint512(10000000000000000UL),
    uint512(100000000000000000UL),
    uint512(1000000000000000000UL),
    uint512(10000000000000000000UL),
    uint512("100000000000000000000"),
    uint512("1000000000000000000000"),
    uint512("10000000000000000000000"),
    uint512("100000000000000000000000"),
    uint512("1000000000000000000000000"),
    uint512("10000000000000000000000000"),
    uint512("100000000000000000000000000"),
    uint512("1000000000000000000000000000"),
    uint512("10000000000000000000000000000"),
    uint512("100000000000000000000000000000"),
    uint512("1000000000000000000000000000000"),
    uint512("10000000000000000000000000000000"),
    uint512("100000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
    uint512("10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),    
    uint512("100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),   
    uint512("1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),  
    uint512("10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"), 
    uint512("100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"), 
    uint512("1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"), 
    uint512("10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"), 
];


template pow10(T)
{
    static if (is(Unqual!T == uint))
        alias pow10 = pow10_32;
    else static if (is(Unqual!T == ulong))
        alias pow10 = pow10_64;
    else static if (is(Unqual!T == uint128))
        alias pow10 = pow10_128;
    else static if (is(Unqual!T == uint256))
        alias pow10 = pow10_256;
    else static if (is(Unqual!T == uint512))
        alias pow10 = pow10_512;
    else static if (is(Unqual!T == ushort))
        alias pow10 = pow10_16;
    else static if (is(Unqual!T == ubyte))
        alias pow10 = pow10_8;
    else
        static assert(0);
}

/* ****************************************************************************************************************** */
/* MAXIMUM COEFFICIENTS THAT CAN BE MULTIPLIED BY 10-POWERS                                                                                                */
/* ****************************************************************************************************************** */

immutable ubyte[3] maxmul10_8 =
[
    255U,
    25U,
    2U,
];

immutable ushort[5] maxmul10_16 =
[
    65535U,
    6553U,
    655U,
    65U,
    6U,
];

immutable uint[10] maxmul10_32 =
[
    4294967295U,
    429496729U,
    42949672U,
    4294967U,
    429496U,
    42949U,
    4294U,
    429U,
    42U,
    4U,
];

immutable ulong[20] maxmul10_64 =
[
    18446744073709551615UL,
    1844674407370955161UL,
    184467440737095516UL,
    18446744073709551UL,
    1844674407370955UL,
    184467440737095UL,
    18446744073709UL,
    1844674407370UL,
    184467440737UL,
    18446744073UL,
    1844674407UL,
    184467440UL,
    18446744UL,
    1844674UL,
    184467UL,
    18446UL,
    1844UL,
    184UL,
    18UL,
    1UL,
];

immutable uint128[39] maxmul10_128 =
[
    uint128("340282366920938463463374607431768211455"), 
    uint128("34028236692093846346337460743176821145"),  
    uint128("3402823669209384634633746074317682114"),
    uint128("340282366920938463463374607431768211"),
    uint128("34028236692093846346337460743176821"),
    uint128("3402823669209384634633746074317682"),
    uint128("340282366920938463463374607431768"),
    uint128("34028236692093846346337460743176"),
    uint128("3402823669209384634633746074317"),
    uint128("340282366920938463463374607431"),
    uint128("34028236692093846346337460743"),
    uint128("3402823669209384634633746074"),
    uint128("340282366920938463463374607"),
    uint128("34028236692093846346337460"),
    uint128("3402823669209384634633746"),
    uint128("340282366920938463463374"),
    uint128("34028236692093846346337"),
    uint128("3402823669209384634633"),
    uint128("340282366920938463463"),
    uint128("34028236692093846346"),
    uint128(3402823669209384634UL),
    uint128(340282366920938463UL),
    uint128(34028236692093846UL),
    uint128(3402823669209384UL),
    uint128(340282366920938UL),
    uint128(34028236692093UL),
    uint128(3402823669209UL),
    uint128(340282366920UL),
    uint128(34028236692UL),
    uint128(3402823669UL),
    uint128(340282366UL),
    uint128(34028236UL),
    uint128(3402823UL),
    uint128(340282UL),
    uint128(34028UL),
    uint128(3402UL),
    uint128(340UL),
    uint128(34UL),
    uint128(3UL),
];

immutable uint256[78] maxmul10_256 =
[
    uint256("115792089237316195423570985008687907853269984665640564039457584007913129639935"), 
    uint256("11579208923731619542357098500868790785326998466564056403945758400791312963993"),  
    uint256("1157920892373161954235709850086879078532699846656405640394575840079131296399"),
    uint256("115792089237316195423570985008687907853269984665640564039457584007913129639"),
    uint256("11579208923731619542357098500868790785326998466564056403945758400791312963"),
    uint256("1157920892373161954235709850086879078532699846656405640394575840079131296"),
    uint256("115792089237316195423570985008687907853269984665640564039457584007913129"),
    uint256("11579208923731619542357098500868790785326998466564056403945758400791312"),
    uint256("1157920892373161954235709850086879078532699846656405640394575840079131"),
    uint256("115792089237316195423570985008687907853269984665640564039457584007913"),
    uint256("11579208923731619542357098500868790785326998466564056403945758400791"),
    uint256("1157920892373161954235709850086879078532699846656405640394575840079"),
    uint256("115792089237316195423570985008687907853269984665640564039457584007"),
    uint256("11579208923731619542357098500868790785326998466564056403945758400"),
    uint256("1157920892373161954235709850086879078532699846656405640394575840"),
    uint256("115792089237316195423570985008687907853269984665640564039457584"),
    uint256("11579208923731619542357098500868790785326998466564056403945758"),
    uint256("1157920892373161954235709850086879078532699846656405640394575"),
    uint256("115792089237316195423570985008687907853269984665640564039457"),
    uint256("11579208923731619542357098500868790785326998466564056403945"),
    uint256("1157920892373161954235709850086879078532699846656405640394"),
    uint256("115792089237316195423570985008687907853269984665640564039"),
    uint256("11579208923731619542357098500868790785326998466564056403"),
    uint256("1157920892373161954235709850086879078532699846656405640"),
    uint256("115792089237316195423570985008687907853269984665640564"),
    uint256("11579208923731619542357098500868790785326998466564056"),
    uint256("1157920892373161954235709850086879078532699846656405"),
    uint256("115792089237316195423570985008687907853269984665640"),
    uint256("11579208923731619542357098500868790785326998466564"),
    uint256("1157920892373161954235709850086879078532699846656"),
    uint256("115792089237316195423570985008687907853269984665"),
    uint256("11579208923731619542357098500868790785326998466"),
    uint256("1157920892373161954235709850086879078532699846"),
    uint256("115792089237316195423570985008687907853269984"),
    uint256("11579208923731619542357098500868790785326998"),
    uint256("1157920892373161954235709850086879078532699"),
    uint256("115792089237316195423570985008687907853269"),
    uint256("11579208923731619542357098500868790785326"),
    uint256("1157920892373161954235709850086879078532"),
    uint256("115792089237316195423570985008687907853"),
    uint256("11579208923731619542357098500868790785"),
    uint256("1157920892373161954235709850086879078"),
    uint256("115792089237316195423570985008687907"),
    uint256("11579208923731619542357098500868790"),
    uint256("1157920892373161954235709850086879"),
    uint256("115792089237316195423570985008687"),
    uint256("11579208923731619542357098500868"),
    uint256("1157920892373161954235709850086"),
    uint256("115792089237316195423570985008"),
    uint256("11579208923731619542357098500"),
    uint256("1157920892373161954235709850"),
    uint256("115792089237316195423570985"),
    uint256("11579208923731619542357098"),
    uint256("1157920892373161954235709"),
    uint256("115792089237316195423570"),
    uint256("11579208923731619542357"),
    uint256("1157920892373161954235"),
    uint256("115792089237316195423"),
    uint256("11579208923731619542"),
    uint256("1157920892373161954"),
    uint256("115792089237316195"),
    uint256(11579208923731619UL),
    uint256(1157920892373161UL),
    uint256(115792089237316UL),
    uint256(11579208923731UL),
    uint256(1157920892373UL),
    uint256(115792089237UL),
    uint256(11579208923UL),
    uint256(1157920892UL),
    uint256(115792089UL),
    uint256(11579208UL),
    uint256(1157920UL),
    uint256(115792UL),
    uint256(11579UL),
    uint256(1157UL),
    uint256(115UL),
    uint256(11UL),
    uint256(1UL),
];

template maxmul10(T)
{
    static if (is(Unqual!T == uint))
        alias maxmul10 = maxmul10_32;
    else static if (is(Unqual!T == ulong))
        alias maxmul10 = maxmul10_64;
    else static if (is(Unqual!T == uint128))
        alias maxmul10 = maxmul10_128;
    else static if (is(Unqual!T == uint256))
        alias maxmul10 = maxmul10_256;
    else static if (is(Unqual!T == ushort))
        alias maxmul10 = maxmul10_16;
    else static if (is(Unqual!T == ubyte))
        alias maxmul10 = maxmul10_8;
    else
        static assert(0);
}



//true on inexact
bool sqrt(U)(ref U x)
if (isAnyUnsigned!U)
{
    // Newton-Raphson: x = (x + n/x) / 2;
    //x 
    if (x <= 1U)
        return false;
    immutable n = x;
    Unqual!U y;
    //1 ..          99   1 x 10^0 .. 99 x 10^0         1 .. 2  //0 - 10^0  <10^1      2 x 10^0, 6x10^0
    //100 ..      9999   1 x 10^2 ...99.99 x 10^2      3 .. 4  //2  -10^1  <10^3      2 x 10^1, 6x10^1
    //10000 ..  999999   1.x 10^4 ...99999.99 x 10^4   5 .. 6  //4  -10^2  <10^5      2 x 10^2, 6x10^2
    auto p = prec(x);
    int power = p & 1 ? p - 1 : p - 2;     

    if (power >= pow10!U.length - 1 || x >= pow10!U[power + 1])
        x = pow10!U[power >> 1] * 6U;
    else
        x = pow10!U[power >> 1] << 1;  //* 2U;   

    do
    {
        y = x;
        x = (x + n / x) >> 1;
    } 
    while (x != y);
    return x * x != n;
}

//true on inexact
bool cbrt(U)(ref U x)
if (isAnyUnsigned!U)
{
    // Newton-Raphson: x = (2x + N/x2)/3
    if (x <= 1U)
        return false;
    immutable n = x;
    Unqual!U y;
    //1 ..          99   1 x 10^0 .. 99 x 10^0         1 .. 2  //0 - 10^0  <10^1      2 x 10^0, 6x10^0
    //100 ..      9999   1 x 10^2 ...99.99 x 10^2      3 .. 4  //2  -10^1  <10^3      2 x 10^1, 6x10^1
    //10000 ..  999999   1.x 10^4 ...99999.99 x 10^4   5 .. 6  //4  -10^2  <10^5      2 x 10^2, 6x10^2
    
    x /= 3U;
    if (!x)
        return true;
    do
    {
        y = x;
        x = ((x << 1) + n / (x * x)) / 3U;
    } 
    while (x != y && x);
    return x * x * x != n;
}

U uparse(U)(string s)
{
    Unqual!U result;
    assert (s.length, "Empty string");
    size_t i = 0;
    if (s.length > 2 && s[0] == '0' && (s[1] == 'x' || s[1] == 'X'))
    {
        i+=2;
        assert (i < s.length, "Empty hexadecimal string");
        while (i < s.length && (s[i] == '0' || s[i] == '_'))
            ++i;
        int width = 0;
        int maxWidth = U.sizeof * 8;
        while (i < s.length)
        {
            assert (width < maxWidth, "Overflow");
            char c = s[i++];
            if (c >= '0' && c <= '9')
            {
                result <<= 4;
                result |= cast(uint)(c - '0');
                width += 4;
            }
            else if (c >= 'A' && c <= 'F')
            {
                result <<= 4;
                result |= cast(uint)(c - 'A' + 10);
                width += 4;
            }
            else if (c >= 'a' && c <= 'f')
            {
                result <<= 4;
                result |= cast(uint)(c - 'a' + 10);
                width += 4;
            }
            else
                assert(c == '_', "Invalid character in input string");
        }
    }
    else
    {
        while (i < s.length)
        {
            char c = s[i++];
            if (c >= '0' && c <= '9')
            {
                bool ovf;
                auto r = fma(result, 10U, cast(uint)(c - '0'), ovf);
                assert(!ovf, "Overflow");
                result = r;
            }
            else
                assert(c == '_', "Invalid character in input string");
        }
    }

    return result;
}

unittest
{
    uint512 x = uparse!uint512("1234567890123456789012345678901234567890");
}
