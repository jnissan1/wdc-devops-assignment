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
        
    def add_arguments(self):
      #  self.parser = argparse.ArgumentParser(description="Env Var to expose")
        self.parser.add_argument("--envexposer", dest="envexposer", help="Env Var to expose", required=True)
        pass

    def prepare(self):
        self.args = self.parser.parse_args()
        self.pod_name = os.environ[self.args.envexposer]
        pass

    def run(self):
        
        if self.pod_name is not None:
            print(self.pod_name)
        else:
            raise Exception("Failed to get the runner pod's name.")

    def on_exception(self, e):
        raise Exception from e

    def on_end(self):
        pass


if __name__ == '__main__':
    try:
        sys.exit(PodExposer().execute())
    except Exception as e:
        print(f"An error occurred: {e}")
        sys.exit(1)
