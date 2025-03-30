from os import getenv
from dotenv import load_dotenv
load_dotenv()

from flask import Flask, Blueprint
from flask_cors import CORS
from src.routes.user_routes import router_user
from src.routes.trasaction_routes import router_transaction
from src.routes.card_roules import card_routes  
from src.routes.email_routes import email_routes
from src.routes.form_routes import form_routes

rout_teste = Blueprint('route', __name__)
@rout_teste.route('/', methods=['GET'])
def teste():
    return "Hello World"

app = Flask(__name__)

app.register_blueprint(rout_teste)
app.register_blueprint(router_user)
app.register_blueprint(router_transaction)
app.register_blueprint(card_routes)
app.register_blueprint(email_routes)
app.register_blueprint(form_routes)

CORS(app)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
