import os
import sys

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../..')))

from base import Base

class PodExposer(Base):
    """
    This class inherits from Base class.
    Its purpose is to access the Pod's name via an environment variable and return it.
    """

    def __init__(self):
        super().__init__()
        self.pod_name = os.environ["HOSTNAME"]

    def add_arguments(self):
        pass

    def prepare(self):
        pass

    def run(self):
        
    #    print(self.pod_name)
    #    print(f"inside def run")
        if self.pod_name is not None:
            print(self.pod_name)
        else:
            raise Exception("Failed to get the runner pod's name.")

    def on_exception(self, e):
        print(f"inside def on_exception")
        raise Exception from e

    def on_end(self):
        print(f"inside def on_end")
        pass


if __name__ == '__main__':
    try:
        sys.exit(PodExposer().execute())
    except Exception as e:
        print(f"An error occurred: {e}")
        sys.exit(1)
