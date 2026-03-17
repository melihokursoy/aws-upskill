'use client';

import { ChevronDown } from 'lucide-react';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '../ui/dropdown-menu';
import { Avatar, AvatarFallback, AvatarImage } from '../ui/avatar';
import { cn } from '../../../lib/utils';

interface AvatarDropdownProps {
  user: {
    name: string;
    familyName: string | null;
    picture: string | null;
    roles: string[];
  };
}

function getInitials(name: string, familyName: string | null): string {
  const first = name.charAt(0).toUpperCase();
  const last = familyName ? familyName.charAt(0).toUpperCase() : '';
  return `${first}${last}`;
}

export function AvatarDropdown({ user }: AvatarDropdownProps) {
  const initials = getInitials(user.name, user.familyName);
  const displayName = user.familyName ? `${user.name} ${user.familyName}` : user.name;
  const isAdmin = user.roles.includes('admin');
  const isModerator = user.roles.includes('moderator');

  return (
    <DropdownMenu>
      <DropdownMenuTrigger
        className={cn(
          'flex items-center gap-2 rounded-[--radius] px-2 py-1 text-sm font-medium',
          'hover:bg-muted focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary'
        )}
      >
        <Avatar className="h-8 w-8">
          {user.picture ? (
            <AvatarImage src={user.picture} alt={displayName} />
          ) : null}
          <AvatarFallback>{initials}</AvatarFallback>
        </Avatar>
        <span>{displayName}</span>
        <ChevronDown className="h-4 w-4 text-muted-foreground" />
      </DropdownMenuTrigger>

      <DropdownMenuContent align="end">
        {(isAdmin || isModerator) && (
          <DropdownMenuItem asChild>
            <a href="/manage">Manage</a>
          </DropdownMenuItem>
        )}
        {isAdmin && (
          <DropdownMenuItem asChild>
            <a href="/admin">Admin</a>
          </DropdownMenuItem>
        )}
        <DropdownMenuSeparator />
        <DropdownMenuItem asChild>
          <a href="/nextapi/sign-out">Logout</a>
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
