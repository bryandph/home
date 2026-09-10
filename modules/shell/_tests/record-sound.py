import json
import os
import sys
with open(os.environ["SOUND_TEST_LOG"], "a") as stream:
    stream.write(json.dumps(sys.argv[1:]) + "\n")
