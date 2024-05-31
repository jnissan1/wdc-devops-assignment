import os
import sys
import requests

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../..')))

from base import Base


class ChuckNorris(Base):
    """
    This class inherits from Base class.
    Its purpose is to read from Chuck Norris jokes API and return only the joke text.
    """

    def __init__(self):
        super().__init__()
        self.chuck_api_url = os.getenv('CHUCK_API', 'https://api.chucknorris.io/jokes/random')

    def add_arguments(self):
        self.parser.add_argument("--url", dest="url", help="url to Chuck Norris API URL", default=self.chuck_api_url)

    def prepare(self):
        pass

    def run(self):
        response = requests.get(self.args.url)
        if response.status_code == 200:
            data = response.json()
            joke = data.get("value", "No joke found.")
            print(joke)
        else:
            raise Exception("Failed to retrieve a joke.")

    def on_exception(self, e):
        raise Exception from e

    def on_end(self):
        pass

if __name__ == '__main__':
    try:
        sys.exit(ChuckNorris().execute())
    except Exception as e:
        print(f"An error occurred: {e}")
        sys.exit(1)
