use lib '.';
use inc::Module::Install;

RTx 'RT-Extension-DebugMemory';
repository('https://github.com/bestpractical/rt-extension-debugmemory');
license  'gplv2';

requires 'Proc::ProcessTable';

sign();
WriteAll();
