#!/bin/bash

# ==========================================
# 0. INTERACTIVE PROMPTS
# ==========================================

# Ask for the project name
read -p "Enter project name (e.g., milad): " PROJ_NAME
if [ -z "$PROJ_NAME" ]; then
  PROJ_NAME="my_bot"
fi

# Ask to install OS dependencies for TgCrypto
read -p "Do you want to install python3-dev and build-essential to fix TgCrypto? (y/n): " FIX_TGCRYPTO

# Ask to create a virtual environment
read -p "Do you want to make a venv inside the directory? (y/n): " MAKE_VENV

# Ask to install Python packages
read -p "Do you want to install python packages here? (y/n): " INSTALL_PKGS

echo ""
echo "🚀 Setting up blueprint for: $PROJ_NAME"
echo "--------------------------------------------------------"

# ==========================================
# 1. OS DEPENDENCIES & SHORTCUTS
# ==========================================

if [[ "$FIX_TGCRYPTO" =~ ^[Yy]$ ]]; then
    echo "📦 Installing build-essential, python3-dev, and python3-venv..."
    sudo apt update
    sudo apt install -y build-essential python3-dev python3-venv
    echo "✅ OS Dependencies installed."
fi

echo "🚀 Installing shell shortcuts (milibots/install-shortcuts)..."
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/milibots/install-shortcuts/main/install.sh)"

# ==========================================
# 2. CREATE DIRECTORIES
# ==========================================

mkdir -p "$PROJ_NAME/helpers"
mkdir -p "$PROJ_NAME/plugins"

# ==========================================
# 3. ROOT FILES
# ==========================================

# .env
cat << 'EOF' > "$PROJ_NAME/.env"
API_ID=1234567
API_HASH=your_api_hash_here
BOT_TOKEN=your_bot_token_here
EOF

# requirements.txt (Using Kurigram instead of pyrogram)
cat << 'EOF' > "$PROJ_NAME/requirements.txt"
Kurigram
TgCrypto
python-dotenv
python-decouple
Flask
SQLAlchemy
EOF

# settings.json
cat << 'EOF' > "$PROJ_NAME/settings.json"
{
    "admins": [],
    "support": {
        "username": "@support"
    }
}
EOF

# texts.json
cat << 'EOF' > "$PROJ_NAME/texts.json"
{
  "welcome_text": "🌟 سلام! به ربات خوش آمدید.\n\nمن یک ربات خام و آماده توسعه هستم."
}
EOF

# config.py
cat << 'EOF' > "$PROJ_NAME/config.py"
import json
from decouple import config

class Config:
    def _load_settings(self):
        with open("settings.json", "r", encoding="utf-8") as f:
            return json.load(f)

    @property
    def API_ID(self):
        return config("API_ID", cast=int)

    @property
    def API_HASH(self):
        return config("API_HASH")

    @property
    def BOT_TOKEN(self):
        return config("BOT_TOKEN")

    @property
    def ADMINS(self):
        return self._load_settings().get("admins", [])

configs = Config()
EOF

# texts.py
cat << 'EOF' > "$PROJ_NAME/texts.py"
import json

class Texts:
    def _load_texts(self):
        with open("texts.json", "r", encoding="utf-8") as file:
            return json.load(file)

    @property
    def WELCOME_TEXT(self):
        return self._load_texts().get("welcome_text", "Welcome to the bot!")

texts = Texts()
EOF

# main.py
cat << 'EOF' > "$PROJ_NAME/main.py"
from pyrogram import Client
from config import configs
from helpers.db import engine, Base
import helpers.models  # Ensure models are imported before creating tables

app = Client(
    "bot_session",
    api_id=configs.API_ID,
    api_hash=configs.API_HASH,
    bot_token=configs.BOT_TOKEN,
    plugins=dict(root="plugins")
)

if __name__ == "__main__":
    # Initialize database tables
    Base.metadata.create_all(bind=engine)
    print("✅ Database tables created successfully")
    
    print("✅ Bot started successfully")
    # Run the Pyrogram client
    app.run()
EOF


# ==========================================
# 4. HELPERS FOLDER
# ==========================================

# helpers/__init__.py
touch "$PROJ_NAME/helpers/__init__.py"

# helpers/db.py
cat << 'EOF' > "$PROJ_NAME/helpers/db.py"
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base, scoped_session

DATABASE_URL = "sqlite:///bot.db"

engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)
db_session = scoped_session(SessionLocal)

Base = declarative_base()

def get_db():
    db = db_session()
    try:
        yield db
    finally:
        db_session.remove()
EOF

# helpers/models.py
cat << 'EOF' > "$PROJ_NAME/helpers/models.py"
from sqlalchemy import Column, Integer, String, Boolean, DateTime
from datetime import datetime
from helpers.db import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    telegram_id = Column(Integer, unique=True, index=True)
    username = Column(String, nullable=True)
    first_name = Column(String, nullable=True)
    last_name = Column(String, nullable=True)
    is_banned = Column(Boolean, default=False)
    joined_at = Column(DateTime, default=datetime.utcnow)
EOF

# helpers/decorators.py
cat << 'EOF' > "$PROJ_NAME/helpers/decorators.py"
from functools import wraps
from datetime import datetime
from helpers.db import SessionLocal
from helpers.models import User

def ensure_user(func):
    @wraps(func)
    async def wrapper(client, update, *args, **kwargs):
        db = SessionLocal()
        try:
            tg_user = update.from_user
            user = db.query(User).filter(User.telegram_id == tg_user.id).first()

            if not user:
                user = User(
                    telegram_id=tg_user.id,
                    username=tg_user.username,
                    first_name=tg_user.first_name,
                    last_name=tg_user.last_name,
                    is_banned=False,
                    joined_at=datetime.utcnow()
                )
                db.add(user)
                db.commit()
                db.refresh(user)

            if user.is_banned:
                return

            update.db_user = user
            return await func(client, update, *args, **kwargs)

        finally:
            db.close()

    return wrapper
EOF

# helpers/kb.py
cat << 'EOF' > "$PROJ_NAME/helpers/kb.py"
from pyrogram.types import InlineKeyboardMarkup, InlineKeyboardButton

class KB:
    @staticmethod
    def menu():
        return InlineKeyboardMarkup(
            [
                [
                    InlineKeyboardButton("💬 درباره ما", callback_data="about")
                ]
            ]
        )
EOF


# ==========================================
# 5. PLUGINS FOLDER
# ==========================================

# plugins/__init__.py
touch "$PROJ_NAME/plugins/__init__.py"

# plugins/commands.py
cat << 'EOF' > "$PROJ_NAME/plugins/commands.py"
from pyrogram import Client, filters
from pyrogram.types import Message
from helpers.decorators import ensure_user
from helpers.kb import KB
from texts import texts

@Client.on_message(filters.command("start") & filters.private)
@ensure_user
async def start_handler(client: Client, message: Message):
    await message.reply_text(
        texts.WELCOME_TEXT,
        reply_markup=KB.menu()
    )
EOF

# plugins/inline.py
cat << 'EOF' > "$PROJ_NAME/plugins/inline.py"
from pyrogram import Client, filters
from pyrogram.types import CallbackQuery
from helpers.decorators import ensure_user

@Client.on_callback_query(filters.regex("^about$"))
@ensure_user
async def about_callback(client: Client, callback: CallbackQuery):
    await callback.answer("این یک ربات پایه ساخته شده با Blueprint است!", show_alert=True)
EOF

# ==========================================
# 6. VIRTUAL ENVIRONMENT & PIP PACKAGES
# ==========================================

cd "$PROJ_NAME" || exit

if [[ "$MAKE_VENV" =~ ^[Yy]$ ]]; then
    echo "🐍 Creating Virtual Environment..."
    python3 -m venv venv
    echo "✅ Venv created."
fi

if [[ "$INSTALL_PKGS" =~ ^[Yy]$ ]]; then
    echo "📦 Installing Python packages (Kurigram, Flask, SQLAlchemy, TgCrypto, etc)..."
    if [[ "$MAKE_VENV" =~ ^[Yy]$ ]]; then
        source venv/bin/activate
        pip install -r requirements.txt
        deactivate
    else
        pip3 install -r requirements.txt
    fi
    echo "✅ Python packages installed."
fi

# ==========================================
# 7. FINISH
# ==========================================

echo ""
echo "✅ Blueprint generated successfully in './$PROJ_NAME'."
echo "--------------------------------------------------------"
echo "To get started:"
echo "1. cd $PROJ_NAME"
if [[ "$MAKE_VENV" =~ ^[Yy]$ ]]; then
    echo "2. source venv/bin/activate"
    echo "3. nano .env (Add BOT_TOKEN, API_ID, API_HASH)"
    echo "4. python3 main.py"
else
    echo "2. nano .env (Add BOT_TOKEN, API_ID, API_HASH)"
    echo "3. python3 main.py"
fi
echo "--------------------------------------------------------"
