#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <assert.h>

#include "hashmap.h"

void
chomp(char* text)
{
    // TODO: remove trailing newline from string
}

int
main(int argc, char* argv[])
{
    if (argc != 3) {
        printf("Usage:\n  %s input N\n", argv[0]);
        return 1;
    }

    FILE* fh = fopen(argv[1], "r");
    if (!fh) {
        perror("open failed");
        return 1;
    }

    long NN = atol(argv[2]);

    hashmap* trips = make_hashmap();
    char temp[128];
    char trip[4];

    while (1) {
        char* line = fgets(temp, 128, fh);
        if (!line) {
            break;
        }

        chomp(line);

        int zz = strlen(line) - 2;
        for (int ii = 0; ii < zz; ++ii) {
            for (int jj = 0; jj < 3; ++jj) {
                trip[jj] = line[ii + jj];
            }
            trip[3] = 0;

            if (hashmap_has(trips, trip)) {
                int count = hashmap_get(trips, trip);
                hashmap_put(trips, trip, count + 1);
            }
            else {
                hashmap_put(trips, trip, 1);
            }
        }
    }

    fclose(fh);

    hashmap_pair tops[NN];
    for (int ii = 0; ii < NN; ++ii) {
        tops[ii].val = 0;
    }

    // TODO: 0 is probably the wrong loop bound here.
    for (int ii = 0; ii < 0; ++ii) {
        hashmap_pair pair = hashmap_get_pair(trips, ii);
        if (!pair.used || pair.tomb) {
            continue;
        }

        int count = pair.val;

        for (int jj = 0; jj < NN; ++jj) {
            if (count > tops[jj].val) {
                hashmap_pair tmp = tops[jj];
                tops[jj] = pair;
                pair = tmp;
            }
        }
    }

    for (int ii = 0; ii < NN; ++ii) {
        hashmap_pair pair = tops[ii];
        printf("%d\t%s\n", pair.val, pair.key);
    }

    free_hashmap(trips);
    return 0;
}
