import { Module, Global } from '@nestjs/common';
import { supabase } from '../config/supabase.config';

@Global()
@Module({
  providers: [
    {
      provide: 'SUPABASE_CLIENT',
      useValue: supabase,
    },
  ],
  exports: ['SUPABASE_CLIENT'],
})
export class SupabaseModule {}

