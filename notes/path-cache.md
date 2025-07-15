Every model has a path, rooting it back to:

 - Course, if possible.
 - User, if possible.
 - DockerTag has no parent, so it's the root.

For example, Grade -> Sub -> Assignment -> Bucket -> Course

Whenever we load a resource, we generally want to also load it's full path. But
it'd be best to cache those paths if only to avoid log spam from DB queries.

The exception is descendants of an object we want, in which case loading the
path for each child and grandchild could produce a really big redundant
structure. That's okay as long as we try to keep duplicates the same, but we
can't build circular structures.

Parents rarely change, so we can just flush the whole cache whenever
that happens.

Current plan:

 - A GenServer called Inkfish.Repo.Cache
 - It contains a nested map from module => id => item
 - get queries are satisfied first from the cache
 - list queries always go to the DB but update the cache
 - cached items always have their path preloaded


