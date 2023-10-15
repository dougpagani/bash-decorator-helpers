# Some problems with these:
# - not transparent (needs $-referencing)
# - demanding (needs explicit wrap each time instead of being baked-in)

time-decorator() {
  local fn=$1
  shift

  echo "Starting function $fn..."
  local start=$(date +%s%N)
  
  $fn "$@"
  
  local end=$(date +%s%N)
  local duration=$(( (end - start) / 1000000 ))  # In milliseconds
  echo "Function $fn took $duration milliseconds."
}
with-perf() {
    time-decorator "$@"
}

myfxn() {
  echo "Doing some work..."
  sleep 1
  echo "Work done."
}

time-decorator myfxn
# or
with-perf myfxn


##############################

generate-decorated() {
  local original_fn=$1
  local decorator=$2
  local decorated_fn="${original_fn}_decorated"

  eval "
    $decorated_fn() {
      $decorator $original_fn \"\$@\"
    }
  "
  echo $decorated_fn
}

myfxn() {
  echo "Doing some work..."
  sleep 1
  echo "Work done."
}

decorated_fn=$(generate-decorated myfxn time-decorator)
$decorated_fn
