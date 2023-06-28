/* This file is lecture notes from CS 3650, Fall 2018 */
/* Author: Nat Tuck */

#ifndef SVEC_H
#define SVEC_H

typedef struct svec {
    int size;
    char** data;
    // TODO: complete struct
} svec;

svec* make_svec();
void  free_svec(svec* sv);

char* svec_get(svec* sv, int ii);
void  svec_put(svec* sv, int ii, char* item);

void svec_push_back(svec* sv, char* item);
void svec_swap(svec* sv, int ii, int jj);

#endif
