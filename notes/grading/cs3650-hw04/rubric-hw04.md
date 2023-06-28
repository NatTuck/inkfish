## Rubric for HW04

Students start with 50 points.

The tests cover functionality, so manual grading is mostly just a sanity check.

### Sanity Check

 - Was this an honest attempt to complete the homework assignment by
   completing the the starter code? If not, let me know.

### General Deductions

 - Inconsistent code formatting (-1 each, max -5).
 - Subjectively bad code (-1 each, max -5), clear comment about why it's bad.
 - Clear logic errors, especially in reguard to pointers / memory access 
   (e.g. function return pointer to stack). 
   (-5 each, max -20), clear comment explaining error.
 - failing to free memory: -2 each / max -8

### Specific Deductions

Vector (max -25 for vector task).

 - Didn't implement expansion logic at all or no notion of capacity. -10.
 - Expanding by adding a constant (e.g. +1) rather than multiplying capacity
   by a constant. -2
 - Missing implementation / no attempt for a svec interface function. -4 each
 - Error in implementation of svec function such that it doesn't correctly
   implement a vector data structure. -1 or -2 each.

Hashmap (max -25 for hashmap task).

 - Obviously bad but non-constant hash function (e.g. "return key[0]"). -2
 - Expansion doesn't double table size. -5
 - Expansion occurs below load factor of 0.25 or above load factor of 0.75: -3
 - No rehashing on expansion. -5
 - Missing implementation / no attempt for for a hashmap interface function. -4 each
 - Error in implementation of hashmap function such that it doesn't correctly
   implement a map data structure. -1 or -2 each.

### Process Issues

 - Binaries, objects, or hidden files submitted: -2

