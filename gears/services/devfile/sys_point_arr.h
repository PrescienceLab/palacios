/* 
   Device File Virtualization Guest Preload Library Helpers

   (c) Akhil Guliani and William Gross, 2015
     
   Adapted from MPI module (c) 2012 Peter Dinda

*/

/*
  This is a mapping between system call number (64 bit Linux)
  and a bit vector whose set bits indicate which of the arguments
  to the givien system call are pointer arguments, and thus need
  to be swizzled by the devfile implementation.
  
*/

long long sys_pointer_arr[323] = {
2,
2,
1,
0,
3,
2,
3,
1,
0,
0,
0,
0,
0,
6,
6,
0,
4,
2,
2,
2,
2,
1,
1,
30,
0,
0,
0,
4,
0,
0,
2,
4,
0,
0,
0,
3,
2,
0,
6,
0,
4,
0,
2,
6,
18,
50,
2,
2,
0,
2,
0,
6,
6,
8,
8,
24,
12,
0,
0,
7,
0,
10,
0,
1,
0,
2,
0,
1,
0,
2,
2,
4,
0,
0,
0,
0,
1,
0,
2,
1,
1,
0,
3,
1,
1,
1,
3,
1,
3,
3,
1,
0,
1,
0,
1,
0,
3,
2,
2,
1,
1,
0,
0,
2,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
2,
2,
7,
7,
0,
7,
0,
0,
0,
0,
0,
0,
1,
7,
4,
1,
3,
3,
1,
0,
0,
2,
3,
2,
0,
0,
0,
2,
2,
4,
0,
0,
0,
2,
0,
0,
0,
0,
0,
2,
3,
1,
0,
5,
1,
2,
1,
0,
1,
3,
23,
1,
1,
1,
8,
1,
1,
2,
0,
0,
5,
1,
0,
0,
10,
0,
0,
0,
0,
0,
0,
0,
0,
7,
7,
6,
7,
7,
6,
3,
3,
2,
3,
3,
2,
0,
1,
25,
4,
4,
0,
2,
0,
8,
4,
6,
0,
0,
0,
0,
0,
0,
2,
1,
0,
10,
0,
6,
12,
2,
0,
0,
2,
2,
2,
12,
0,
2,
8,
0,
3,
0,
8,
2,
3,
9,
1,
18,
26,
2,
6,
4,
20,
7,
7,
0,
0,
0,
0,
2,
0,
12,
2,
2,
2,
2,
6,
6,
2,
10,
10,
5,
6,
2,
2,
62,
13,
0,
1,
6,
10,
0,
0,
2,
28,
6,
18,
2,
0,
0,
0,
12,
2,
6,
2,
0,
0,
0,
1,
0,
2,
2,
8,
1,
18,
0,
0,
12,
14,
14,
2,
0,
2,
0,
7,
10,
10,
0,
2,
2,
2,
6,
4,
1,
1,
8,
2,
14
};

