from scipy.io import loadmat
from pystoi import stoi
import sys
d=loadmat(sys.argv[1],squeeze_me=True)
print(format(stoi(d['reference'],d['processed'],int(d['fs']),extended=False),'.17g'))
