"""initial ludo schema

Creates every table used by the Ludo backend. Each step is guarded so the
migration is safe on both fresh databases and the shared Supabase instance
where some tables already exist.

Revision ID: 42f7893f3498
Revises:
Create Date: 2026-08-25 23:05:38.616720

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision: str = '42f7893f3498'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _tables() -> set:
    bind = op.get_bind()
    insp = inspect(bind)
    return set(insp.get_table_names())


def upgrade() -> None:
    existing = _tables()

    if 'ludo_users' not in existing:
        op.create_table(
            'ludo_users',
            sa.Column('id', sa.Integer(), nullable=False),
            sa.Column('username', sa.String(length=50), nullable=False),
            sa.Column('email', sa.String(length=120), nullable=False),
            sa.Column('hashed_password', sa.String(length=255), nullable=False),
            sa.Column('avatar', sa.String(length=10), nullable=False),
            sa.Column('coins', sa.Integer(), nullable=False),
            sa.Column('gems', sa.Integer(), nullable=False),
            sa.Column('wins', sa.Integer(), nullable=False),
            sa.Column('losses', sa.Integer(), nullable=False),
            sa.Column('level', sa.Integer(), nullable=False),
            sa.Column('xp', sa.Integer(), nullable=False),
            sa.Column('is_active', sa.Boolean(), nullable=False),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
            sa.PrimaryKeyConstraint('id'),
        )
        op.create_index(op.f('ix_ludo_users_id'), 'ludo_users', ['id'], unique=False)
        op.create_index(op.f('ix_ludo_users_username'), 'ludo_users', ['username'], unique=True)
        op.create_index(op.f('ix_ludo_users_email'), 'ludo_users', ['email'], unique=True)

    if 'ludo_rooms' not in existing:
        op.create_table(
            'ludo_rooms',
            sa.Column('id', sa.Integer(), nullable=False),
            sa.Column('code', sa.String(length=6), nullable=False),
            sa.Column('name', sa.String(length=100), nullable=False),
            sa.Column('host_id', sa.Integer(), nullable=False),
            sa.Column('max_players', sa.Integer(), nullable=False),
            sa.Column('bet_amount', sa.Integer(), nullable=False),
            sa.Column('status', sa.String(length=20), nullable=False),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
            sa.ForeignKeyConstraint(['host_id'], ['ludo_users.id']),
            sa.PrimaryKeyConstraint('id'),
        )
        op.create_index(op.f('ix_ludo_rooms_id'), 'ludo_rooms', ['id'], unique=False)
        op.create_index(op.f('ix_ludo_rooms_code'), 'ludo_rooms', ['code'], unique=True)

    if 'ludo_room_players' not in existing:
        op.create_table(
            'ludo_room_players',
            sa.Column('id', sa.Integer(), nullable=False),
            sa.Column('room_id', sa.Integer(), nullable=False),
            sa.Column('user_id', sa.Integer(), nullable=False),
            sa.Column('color', sa.String(length=10), nullable=True),
            sa.Column('seat', sa.Integer(), nullable=False),
            sa.Column('is_ready', sa.Boolean(), nullable=False),
            sa.Column('joined_at', sa.DateTime(timezone=True), nullable=False),
            sa.ForeignKeyConstraint(['room_id'], ['ludo_rooms.id']),
            sa.ForeignKeyConstraint(['user_id'], ['ludo_users.id']),
            sa.PrimaryKeyConstraint('id'),
            sa.UniqueConstraint('room_id', 'user_id', name='uq_room_user'),
        )
        op.create_index(op.f('ix_ludo_room_players_id'), 'ludo_room_players', ['id'], unique=False)

    if 'ludo_games' not in existing:
        op.create_table(
            'ludo_games',
            sa.Column('id', sa.Integer(), nullable=False),
            sa.Column('room_id', sa.Integer(), nullable=True),
            sa.Column('mode', sa.String(length=20), nullable=False),
            sa.Column('status', sa.String(length=20), nullable=False),
            sa.Column('current_turn', sa.String(length=10), nullable=False),
            sa.Column('dice_value', sa.Integer(), nullable=True),
            sa.Column('six_streak', sa.Integer(), nullable=False),
            sa.Column('state', sa.JSON(), nullable=False),
            sa.Column('winner_id', sa.Integer(), nullable=True),
            sa.Column('started_at', sa.DateTime(timezone=True), nullable=False),
            sa.Column('finished_at', sa.DateTime(timezone=True), nullable=True),
            sa.ForeignKeyConstraint(['room_id'], ['ludo_rooms.id']),
            sa.ForeignKeyConstraint(['winner_id'], ['ludo_users.id']),
            sa.PrimaryKeyConstraint('id'),
        )
        op.create_index(op.f('ix_ludo_games_id'), 'ludo_games', ['id'], unique=False)

    if 'ludo_moves' not in existing:
        op.create_table(
            'ludo_moves',
            sa.Column('id', sa.Integer(), nullable=False),
            sa.Column('game_id', sa.Integer(), nullable=False),
            sa.Column('user_id', sa.Integer(), nullable=False),
            sa.Column('color', sa.String(length=10), nullable=False),
            sa.Column('dice_value', sa.Integer(), nullable=False),
            sa.Column('token_index', sa.Integer(), nullable=False),
            sa.Column('from_pos', sa.Integer(), nullable=False),
            sa.Column('to_pos', sa.Integer(), nullable=False),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
            sa.ForeignKeyConstraint(['game_id'], ['ludo_games.id']),
            sa.ForeignKeyConstraint(['user_id'], ['ludo_users.id']),
            sa.PrimaryKeyConstraint('id'),
        )
        op.create_index(op.f('ix_ludo_moves_id'), 'ludo_moves', ['id'], unique=False)

    if 'ludo_match_results' not in existing:
        op.create_table(
            'ludo_match_results',
            sa.Column('id', sa.Integer(), nullable=False),
            sa.Column('game_id', sa.Integer(), nullable=False),
            sa.Column('user_id', sa.Integer(), nullable=False),
            sa.Column('color', sa.String(length=10), nullable=False),
            sa.Column('placement', sa.Integer(), nullable=False),
            sa.Column('coins_earned', sa.Integer(), nullable=False),
            sa.Column('xp_earned', sa.Integer(), nullable=False),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
            sa.ForeignKeyConstraint(['game_id'], ['ludo_games.id']),
            sa.ForeignKeyConstraint(['user_id'], ['ludo_users.id']),
            sa.PrimaryKeyConstraint('id'),
        )
        op.create_index(op.f('ix_ludo_match_results_id'), 'ludo_match_results', ['id'], unique=False)

    existing = _tables()
    if 'ludo_purchases' not in existing:
        op.create_table(
            'ludo_purchases',
            sa.Column('id', sa.Integer(), nullable=False),
            sa.Column('user_id', sa.Integer(), nullable=False),
            sa.Column('item_id', sa.String(length=50), nullable=False),
            sa.Column('price_coins', sa.Integer(), nullable=False),
            sa.Column('price_gems', sa.Integer(), nullable=False),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
            sa.ForeignKeyConstraint(['user_id'], ['ludo_users.id']),
            sa.PrimaryKeyConstraint('id'),
            sa.UniqueConstraint('user_id', 'item_id', name='uq_user_item'),
        )
        op.create_index(op.f('ix_ludo_purchases_id'), 'ludo_purchases', ['id'], unique=False)
        op.create_index(op.f('ix_ludo_purchases_user_id'), 'ludo_purchases', ['user_id'], unique=False)


def downgrade() -> None:
    existing = _tables()
    if 'ludo_purchases' in existing:
        op.drop_index(op.f('ix_ludo_purchases_user_id'), table_name='ludo_purchases')
        op.drop_index(op.f('ix_ludo_purchases_id'), table_name='ludo_purchases')
        op.drop_table('ludo_purchases')
    if 'ludo_match_results' in existing:
        op.drop_table('ludo_match_results')
    if 'ludo_moves' in existing:
        op.drop_table('ludo_moves')
    if 'ludo_games' in existing:
        op.drop_table('ludo_games')
    if 'ludo_room_players' in existing:
        op.drop_table('ludo_room_players')
    if 'ludo_rooms' in existing:
        op.drop_table('ludo_rooms')
    if 'ludo_users' in existing:
        op.drop_table('ludo_users')
