"""add city to users

Revision ID: d1e2f3a4b5c6
Revises: b0f4c2d8a901
Create Date: 2026-05-05

"""
from alembic import op
import sqlalchemy as sa

revision = 'd1e2f3a4b5c6'
down_revision = 'c1a2b3c4d5e6'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('users', sa.Column('city', sa.String(100), nullable=True))


def downgrade() -> None:
    op.drop_column('users', 'city')
