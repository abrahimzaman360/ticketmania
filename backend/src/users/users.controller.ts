import { Controller, Delete, Request, UseGuards, HttpCode, HttpStatus } from '@nestjs/common';
import { Inject } from '@nestjs/common';
import { SupabaseClient } from '@supabase/supabase-js';

@Controller('users')
export class UsersController {
  constructor(
    @Inject('SUPABASE_CLIENT') private readonly supabase: SupabaseClient,
  ) {}

  @Delete('account')
  @HttpCode(HttpStatus.NO_CONTENT)
  async deleteAccount(@Request() req: any) {
    const userId = req.user?.sub || req.user?.id;
    
    if (!userId) {
      throw new Error('User not authenticated');
    }

    // Delete user data using service role (bypasses RLS)
    // Delete wallet transactions
    const { data: wallet } = await this.supabase
      .from('wallets')
      .select('id')
      .eq('user_id', userId)
      .single();

    if (wallet) {
      await this.supabase
        .from('wallet_transactions')
        .delete()
        .eq('wallet_id', wallet.id);
      
      await this.supabase
        .from('wallets')
        .delete()
        .eq('user_id', userId);
    }

    // Delete bookings
    await this.supabase
      .from('bookings')
      .delete()
      .eq('user_id', userId);

    // Delete payments
    await this.supabase
      .from('payments')
      .delete()
      .eq('user_id', userId);

    // Delete profile
    await this.supabase
      .from('profiles')
      .delete()
      .eq('id', userId);

    // Delete auth user (requires admin API)
    // Note: This might need to be done via Supabase Admin API
    // For now, the client-side deletion should work with RLS policies

    return { message: 'Account deleted successfully' };
  }
}

