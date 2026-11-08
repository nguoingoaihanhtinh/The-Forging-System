/// Reception cancels only a package waiting to start; cancelling a running one is an admin job.
bool canCancelPackage({required bool isAdmin, required bool scheduled}) =>
    scheduled || isAdmin;
