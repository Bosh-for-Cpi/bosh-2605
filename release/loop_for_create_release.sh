#!/bin/bash

# loop for create bosh release
for i in $(seq 1 20)
do
  bosh create release --force
done
