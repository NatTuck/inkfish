
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>

// TODO: sudo apt install libbsd-dev
// This provides strlcpy
// See "man strlcpy"
#include <bsd/string.h>
#include <string.h>

#include "hashmap.h"

/*
typedef struct hashmap_pair {
    char key[4]; // null terminated strings
    int  val;
    bool used;
    bool tomb;
} hashmap_pair;

typedef struct hashmap {
    int size;
    int ents;
    hashmap_pair* data;
} hashmap;
*/

int
hash(char* key)
{
    int yy = 0;
    for (int ii = 0; key[ii]; ++ii) {
        // yy *= 67;
        yy *= 97;
        yy += key[ii];
    }
    return yy;
}

hashmap*
make_hashmap_presize(int nn)
{
    hashmap* hh = calloc(1, sizeof(hashmap));
    hh->size = nn;
    hh->ents = 0;
    hh->data = calloc(hh->size, sizeof(hashmap_pair));
    return hh;
}

hashmap*
make_hashmap()
{
    return make_hashmap_presize(4);
}

void
free_hashmap(hashmap* hh)
{
    free(hh->data);
    free(hh);
}

void
hashmap_grow(hashmap* hh)
{
    int size = hh->size;
    hashmap_pair* data = hh->data;

    hh->size = size * 2;
    hh->data = calloc(hh->size, sizeof(hashmap_pair));
    hh->ents = 0;

    for (int ii = 0; ii < size; ++ii) {
        hashmap_pair pair = data[ii];
        if (!pair.used) {
            continue;
        }

        hashmap_put(hh, pair.key, pair.val);
    }

    free(data);
}

int
hashmap_has(hashmap* hh, char* kk)
{
    return hashmap_get(hh, kk) != -1;
}

int
hashmap_get(hashmap* hh, char* kk)
{
    int ii = hash(kk) % hh->size;
    hashmap_pair* pair;

    while (1) {
        pair = &(hh->data[ii]);
        if (!pair->used && !pair->tomb) {
            return -1;
        }

        if (strncmp(pair->key, kk, 3) == 0) {
            return pair->val;
        }

        ii = (ii + 1) % hh->size;
    }
}

void
hashmap_put(hashmap* hh, char* kk, int vv)
{
    for (int ii = 0; ii < 3; ++ii) {
        if (!isalpha(kk[ii])) {
            printf("%s: %d - %d\n", kk, ii, kk[ii]);
        }
    }

    if (2*hh->ents > hh->size) {
        hashmap_grow(hh);
    }

    int ii = hash(kk) % hh->size;
    hashmap_pair* pair;

    while (1) {
        pair = &(hh->data[ii]);
        if (!pair->used || pair->tomb || strncmp(pair->key, kk, 3) == 0) {
            break;
        }
        ii = (ii + 1) % hh->size;
    }

    if (!pair->tomb) {
        hh->ents += 1;
    }

    pair->used = 1;
    pair->tomb = 0;
    strlcpy(&(pair->key[0]), kk, 4);
    pair->val = vv;
}

void
hashmap_del(hashmap* hh, char* kk)
{
    int ii = hash(kk) % hh->size;
    hashmap_pair* pair;

    while (1) {
        pair = &(hh->data[ii]);
        if (!pair->used) {
            return;
        }

        if (strncmp(pair->key, kk, 3) == 0) {
            pair->used = 0;
            pair->tomb = 1;
            break;
        }

        ii = (ii + 1) % hh->size;
    }
}

hashmap_pair
hashmap_get_pair(hashmap* hh, int ii)
{
    return hh->data[ii];
}

void
hashmap_dump(hashmap* hh)
{
    printf("== hashmap dump ==\n");
    printf("size: %d, ents %d\n", hh->size, hh->ents);
    for (int ii = 0; ii < hh->size; ++ii) {
        hashmap_pair pair = hh->data[ii];
        printf(
            "#%d= u:%d,t:%d %c%c%c => %d\n",
            ii,
            pair.used,
            pair.tomb,
            pair.key[0],
            pair.key[1],
            pair.key[2],
            pair.val
        );
    }
    printf("\n");
}
